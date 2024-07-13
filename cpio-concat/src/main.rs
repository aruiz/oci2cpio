#![feature(ascii_char)]

use std::{
    fs::File,
    io::{BufReader, Read, Write},
    mem::{size_of, zeroed},
    path::Path,
    process::ExitCode,
    ptr::{slice_from_raw_parts, slice_from_raw_parts_mut},
};

#[derive(Debug)]
#[repr(C)]
struct NewCEntry {
    sig: [std::ascii::Char; 6],
    inum: [std::ascii::Char; 8],
    mode: [std::ascii::Char; 8],
    uid: [std::ascii::Char; 8],
    gid: [std::ascii::Char; 8],
    nlinks: [std::ascii::Char; 8],
    mtime: [std::ascii::Char; 8],
    size: [std::ascii::Char; 8],
    maj: [std::ascii::Char; 8],
    min: [std::ascii::Char; 8],
    spemaj: [std::ascii::Char; 8],
    spemin: [std::ascii::Char; 8],
    pathsize: [std::ascii::Char; 8],
    sum: [std::ascii::Char; 8],
}

impl NewCEntry {
    fn new_trailer(is_crc: bool) -> NewCEntry {
        let mut ret: NewCEntry = unsafe { zeroed() };

        ret.sig = match is_crc {
            true => unsafe { b"070701".as_ascii_unchecked() }.clone(),
            false => unsafe { b"070702".as_ascii_unchecked() }.clone(),
        };

        ret.pathsize = unsafe { b"0000000b".as_ascii_unchecked() }.clone();

        ret
    }
}

fn check_input_files_exist(files: &[String]) -> bool {
    files
        .iter()
        .map(|f| {
            let ret = Path::new(f).exists();
            if !ret {
                eprintln!("{0} does not exist", f);
            }
            ret
        })
        .reduce(|a, b| a && b)
        .unwrap()
}

fn process_file(input: &String, output: &mut dyn Write) {
    let input_file = File::open(input).unwrap(); //FIXME: Handle cases
    let mut input_buf = BufReader::new(input_file);

    let mut header: NewCEntry = unsafe { zeroed() };

    let header_buf: *mut [u8] = slice_from_raw_parts_mut(
        &mut header as *mut NewCEntry as *mut u8,
        size_of::<NewCEntry>(),
    );

    loop {
        let _ = input_buf.read_exact(unsafe { &mut *header_buf });

        if header.sig.as_str() != "070701" && header.sig.as_str() != "070702" {
            //TODO: return error
            break;
        }

        let path_size = u32::from_str_radix(header.pathsize.as_str(), 16).unwrap();
        // Path buffer length must be aligned to 32 bit from the beginning of the header
        let path_buffer_size = ((size_of::<NewCEntry>() as u32 + path_size) as f32
            / size_of::<u32>() as f32)
            .ceil() as u32
            * 4
            - size_of::<NewCEntry>() as u32;

        let file_size = u32::from_str_radix(header.size.as_str(), 16).unwrap();
        let file_buffer_size = (file_size as f32 / size_of::<u32>() as f32).ceil() as u32 * 4;

        output.write(unsafe { &mut *header_buf }).unwrap(); //FIXME: check error case

        //TODO: Write through one file to the other
        let mut path_buffer: Vec<u8> = vec![0; path_buffer_size as usize];
        let mut content_buffer: Vec<u8> = vec![0; file_buffer_size as usize];

        input_buf.read_exact(&mut path_buffer).unwrap();

        if path_size == 11 && &path_buffer[0..11] == b"TRAILER!!!\0" {
            break;
        }

        input_buf.read_exact(&mut content_buffer).unwrap();

        output.write(&path_buffer).unwrap();
        output.write(&content_buffer).unwrap();
    }
}

fn main() -> ExitCode {
    let mut args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage {0} ARCHIVE1 [ARCHIVE2...] OUTPUT_ARCHIVE", args[0]);
        eprintln!("Not enough arguments were specified");
        return ExitCode::FAILURE;
    }
    args.remove(0);
    let mut output = File::create(Path::new(&args.pop().unwrap())).unwrap(); //FIXME: handle error states

    if !check_input_files_exist(&args) {
        return ExitCode::FAILURE;
    }

    for input in args {
        process_file(&input, &mut output);
    }

    let trailer = NewCEntry::new_trailer(false);
    let trailer_ptr = slice_from_raw_parts(
        &trailer as *const NewCEntry as *const u8,
        size_of::<NewCEntry>(),
    );
    output.write(unsafe { &*trailer_ptr }).unwrap();
    output.write(b"TRAILER!!!\0\0\0\0\0\0\0\0").unwrap();

    ExitCode::SUCCESS
}
