use puremp3;
use std::env;
use std::fs::File;
use std::io::Write;

const PREC: i32 = 10;

fn parse_args() -> (String, String, String) {
    // Parse command line arguments
    // Usage: ./dfpwm-encode <input.mp3> <output_left.dfpwm> <output_right.dfpwm>
    let args: Vec<String> = env::args().collect();
    if args.len() != 4 && args.len() != 3 {
        println!("Usage: ./dfpwm-encode <input.mp3> <output_left.dfpwm> <output_right.dfpwm>");
        println!("Usage: ./dfpwm-encode <input.mp3> <left_right_merged_output.dfpwm> (merged left and right channel in single file, left then right for chunk of size 8*1024 bytes)");
        std::process::exit(1);
    }
    if args.len() == 3 {
        return (args[1].clone(), args[2].clone(), String::from(""));
    } else {
        return (args[1].clone(), args[2].clone(), args[3].clone());
    }
}

fn encode_dfpwm(input_data: &[f32]) -> Vec<u8> {
    let mut charge = 0;
    let mut strength = 0;
    let mut previous_bit = false;

    let out_length = input_data.len() / 8;

    let mut result = Vec::with_capacity(out_length);

    for i in 0..out_length {
        let mut this_byte = 0;

        for j in 0..8 {
            let level = (input_data[i * 8 + j] * 127.0) as i32;

            let current_bit = level > charge || (level == charge && charge == 127);
            let target = if current_bit { 127 } else { -128 };

            let next_charge = charge + ((strength * (target - charge) + (1 << (PREC - 1))) >> PREC);
            if next_charge == charge && next_charge != target {
                charge += if current_bit { 1 } else { -1 };
            }

            let z = if current_bit == previous_bit {
                (1 << PREC) - 1
            } else {
                0
            };
            let mut next_strength = strength;
            if strength != z {
                next_strength += if current_bit == previous_bit { 1 } else { -1 };
            }
            if next_strength < 2 << (PREC - 8) {
                next_strength = 2 << (PREC - 8);
            }

            charge = next_charge;
            strength = next_strength;
            previous_bit = current_bit;

            this_byte = (this_byte >> 1) + if current_bit { 128 } else { 0 };
        }

        result.push(this_byte as u8);
    }

    result
}

fn convert_audio(input_audio_path: &String) -> (Vec<u8>, Vec<u8>) {
    let data = std::fs::read(input_audio_path).expect("Failed to open audio file");
    let (_, sample) = puremp3::read_mp3(&data[..]).expect("Invalid MP3");

    let mut audio_left_samples = Vec::new();
    let mut audio_right_samples = Vec::new();

    for (left, right) in sample {
        audio_left_samples.push(left as f32);
        audio_right_samples.push(right as f32);
    }

    let left_channel = encode_dfpwm(&audio_left_samples);
    let right_channel = encode_dfpwm(&audio_right_samples);
    return (left_channel, right_channel);

    // for (left, right) in sample {
    //     audio_samples.push(left as f32);
    // }
    //
    // audio_samples.iter().collect::<Vec<u8>>()
}

fn main() {
    let (mp3_path, left_output_path, right_output_path) = parse_args();

    if right_output_path == "" {
        let (left_channel, right_channel) = convert_audio(&mp3_path);

        let mut merged_file =
            File::create(left_output_path).expect("Failed to create merged output file");

        let chunk_size = 8 * 1024;
        let channel_size = left_channel.len();

        for i in 0..(channel_size / chunk_size) {
            merged_file
                .write_all(&left_channel[i * chunk_size..(i + 1) * chunk_size])
                .expect("Failed to write merged output file");
            merged_file
                .write_all(&right_channel[i * chunk_size..(i + 1) * chunk_size])
                .expect("Failed to write merged output file");
        }
        merged_file
            .write_all(&left_channel[channel_size - (channel_size % chunk_size)..])
            .expect("Failed to write merged output file");
        merged_file
            .write_all(&right_channel[channel_size - (channel_size % chunk_size)..])
            .expect("Failed to write merged output file");
        merged_file
            .flush()
            .expect("Failed to flush merged output file");
        println!("done");
        return;
    } else {
        let (left_channel, right_channel) = convert_audio(&mp3_path);

        let mut left_file =
            File::create(left_output_path).expect("Failed to create left output file");
        left_file
            .write_all(&left_channel[..])
            .expect("Failed to write left output file");
        left_file.flush().expect("Failed to flush left output file");
        let mut right_file =
            File::create(right_output_path).expect("Failed to create right output file");
        right_file
            .write_all(&right_channel[..])
            .expect("Failed to write right output file");
        right_file
            .flush()
            .expect("Failed to flush right output file");
        println!("done");
    }
}
