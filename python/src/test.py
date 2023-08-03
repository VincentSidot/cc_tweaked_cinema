from pydub import AudioSegment
import numpy as np


SAMPLE_RATE = 49152
PREC = 10

def encode_dfpwm(input_data):
    charge = 0
    strength = 0
    previous_bit = False

    out_length = len(input_data) // 8

    for i in range(out_length):
        this_byte = 0

        for j in range(8):
            level = int(input_data[i * 8 + j] * 127)

            current_bit = (level > charge) or (level == charge and charge == 127)
            target = 127 if current_bit else -128

            next_charge = charge + ((strength * (target - charge) + (1 << (PREC - 1))) >> PREC)
            if next_charge == charge and next_charge != target:
                next_charge += 1 if current_bit else -1

            z = (1 << PREC) - 1 if current_bit == previous_bit else 0
            next_strength = strength
            if strength != z:
                next_strength += 1 if current_bit == previous_bit else -1
            if next_strength < 2 << (PREC - 8):
                next_strength = 2 << (PREC - 8)

            charge = next_charge
            strength = next_strength
            previous_bit = current_bit

            this_byte = (this_byte >> 1) + 128 if current_bit else this_byte >> 1

        yield this_byte

def pydub_to_np(audio):
    """
    Converts pydub audio segment into np.float32 of shape [duration_in_seconds*sample_rate, channels],
    where each value is in range [-1.0, 1.0].
    Returns tuple audio_np_array.
    """
    channel_sounds = audio.split_to_mono()
    samples = [s.get_array_of_samples() for s in channel_sounds]
    fp_arr = np.array(samples).T.astype(np.float32)
    fp_arr /= np.iinfo(samples[0].typecode).max
    return fp_arr


def convert_audio(input_audio_path):
    input_audio = AudioSegment.from_file(input_audio_path, format="mp3")
    input_audio = input_audio.set_frame_rate(SAMPLE_RATE)
    input_data = pydub_to_np(input_audio)
    left_channel = input_data[:, 0]
    right_channel = input_data[:, 1]
    # encode left channel with previous function
    # left_encoded_data = better_encode_dfpwm(left_channel)
    return encode_dfpwm(left_channel)


mp3_path = "../download/A5uoWPoTv4w/audio.mp3"
left_output_path = "../lua/audioL.dfpwm"
right_output_path = "../lua/audioR.dfpwm"
left_channel = convert_audio(mp3_path)

with open(left_output_path, "wb") as f:
    f.write(bytes(left_channel))

print("done")
