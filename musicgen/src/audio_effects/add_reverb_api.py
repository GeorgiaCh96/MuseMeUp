"""
Add reverb to an audio file using Pedalboard.

The audio file is read in chunks, using nearly no memory.
This should be one of the fastest possible ways to add reverb to a file
while also using as little memory as possible.

On my laptop, this runs about 58x faster than real-time
(i.e.: processes a 60-second file in ~1 second.)

Requirements: `pip install PySoundFile tqdm pedalboard`
Note that PySoundFile requires a working libsndfile installation.
"""

import argparse
import os
import sys
import time
import warnings

import numpy as np
import soundfile as sf
from tqdm import tqdm
from tqdm.std import TqdmWarning

from pedalboard import Reverb

BUFFER_SIZE_SAMPLES = 1024 * 16
NOISE_FLOOR = 1e-4


from midi2audio import FluidSynth


def convert(input_file, output_file):
    #fs = FluidSynth(sound_font=r"C:\Users\Vasilis Papadopoulos\Downloads\MuseScore_General.sf2", sample_rate=44100)
    fs = FluidSynth(sample_rate=44100)
    fs.midi_to_audio(input_file, output_file)
    
    #add_reverb(output_file, output_file='audio_files/output_reverb1.wav')
    #os.remove('audio_files/output.mp3')

    timestamp = int(time.time())
    answer = f'audio_files/output_reverb{timestamp}.wav'
    answer = os.path.abspath(answer)
    answer = add_reverb_new(output_file, output_file=answer)
    os.remove(r'..\midiFiles\output.mp3')
    return answer

    
def get_num_frames(f: sf.SoundFile) -> int:
    # On some platforms and formats, f.frames == -1L.
    # Check for this bug and work around it:
    if len(f) > 2 ** 32:
        f.seek(0)
        last_position = f.tell()
        while True:
            # Seek through the file in chunks, returning
            # if the file pointer stops advancing.
            f.seek(1024 * 1024 * 1024, sf.SEEK_CUR)
            new_position = f.tell()
            if new_position == last_position:
                f.seek(0)
                return new_position
            else:
                last_position = new_position
    else:
        return len(f)

def add_reverb_new(input_file: str, output_file: str, room_size=0.5, damping=0.5, wet_level=0.33, dry_level=0.5, width=1.0, freeze_mode=0.0, cut_reverb_tail=False):
    """Applies reverb to an audio file and saves the result."""

    reverb = Reverb(
        room_size=room_size,
        damping=damping,
        wet_level=wet_level,
        dry_level=dry_level,
        width=width,
        freeze_mode=freeze_mode
    )

    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)

    with sf.SoundFile(input_file) as infile:
        with sf.SoundFile(
            output_file,
            'w',
            samplerate=infile.samplerate,
            channels=infile.channels,
        ) as outfile:
            length = infile.frames
            length_seconds = length / infile.samplerate
            print(f"Adding reverb to {length_seconds:.2f} seconds of audio...")

            with tqdm(total=length_seconds, desc="Processing Reverb") as t:
                for dry_chunk in infile.blocks(BUFFER_SIZE_SAMPLES, frames=length):
                    effected_chunk = reverb.process(dry_chunk, sample_rate=infile.samplerate, reset=False)
                    outfile.write(effected_chunk)
                    t.update(len(dry_chunk) / infile.samplerate)

            if not cut_reverb_tail:
                while True:
                    tail_chunk = reverb.process(
                        np.zeros((BUFFER_SIZE_SAMPLES, infile.channels), np.float32),
                        sample_rate=infile.samplerate,
                        reset=False,
                    )
                    if np.amax(np.abs(tail_chunk)) < NOISE_FLOOR:
                        break
                    outfile.write(tail_chunk)

    

    print("Reverb processing complete.")
    return output_file

"""
def add_reverb(input_file, output_file):
    ### change this so it can as input an mp3 file
    warnings.filterwarnings("ignore", category=TqdmWarning)

    parser = argparse.ArgumentParser(description="Add reverb to an audio file.")
   
    # Instantiate the Reverb object early so we can read its defaults for the argparser --help:
    reverb = Reverb()

    parser.add_argument("--room-size", type=float, default=reverb.room_size)
    parser.add_argument("--damping", type=float, default=reverb.damping)
    parser.add_argument("--wet-level", type=float, default=reverb.wet_level)
    parser.add_argument("--dry-level", type=float, default=reverb.dry_level)
    parser.add_argument("--width", type=float, default=reverb.width)
    parser.add_argument("--freeze-mode", type=float, default=reverb.freeze_mode)

    parser.add_argument(
        "-y",
        "--overwrite",
        action="store_true",
        help="If passed, overwrite the output file if it already exists.",
    )

    parser.add_argument(
        "--cut-reverb-tail",
        action="store_true",
        help=(
            "If passed, remove the reverb tail to the end of the file. "
            "The output file will be identical in length to the input file."
        ),
    )
    args = parser.parse_args()

    for arg in ('room_size', 'damping', 'wet_level', 'dry_level', 'width', 'freeze_mode'):
        setattr(reverb, arg, getattr(args, arg))

    #if not args.output_file:
    #    args.output_file = args.input_file + ".reverb.wav"
    args.input_file = input_file
    args.output_file = output_file

    sys.stderr.write(f"Opening {args.input_file}...\n")

    with sf.SoundFile(args.input_file) as input_file:
        sys.stderr.write(f"Writing to {args.output_file}...\n")
        if os.path.isfile(args.output_file) and not args.overwrite:
            raise ValueError(
                f"Output file {args.output_file} already exists! (Pass -y to overwrite.)"
            )
        with sf.SoundFile(
            args.output_file,
            'w',
            samplerate=input_file.samplerate,
            channels=input_file.channels,
        ) as output_file:
            length = get_num_frames(input_file)
            length_seconds = length / input_file.samplerate
            sys.stderr.write(f"Adding reverb to {length_seconds:.2f} seconds of audio...\n")
            with tqdm(
                total=length_seconds,
                desc="Adding reverb...",
                bar_format=(
                    "{percentage:.0f}%|{bar}| {n:.2f}/{total:.2f} seconds processed"
                    " [{elapsed}<{remaining}, {rate:.2f}x]"
                ),
                # Avoid a formatting error that occurs if
                # TQDM tries to print before we've processed a block
                delay=1000,
            ) as t:
                for dry_chunk in input_file.blocks(BUFFER_SIZE_SAMPLES, frames=length):
                    # Actually call Pedalboard here:
                    # (reset=False is necessary to allow the reverb tail to
                    # continue from one chunk to the next.)
                    effected_chunk = reverb.process(
                        dry_chunk, sample_rate=input_file.samplerate, reset=False
                    )
                    # print(effected_chunk.shape, np.amax(np.abs(effected_chunk)))
                    output_file.write(effected_chunk)
                    t.update(len(dry_chunk) / input_file.samplerate)
                    t.refresh()
            if not args.cut_reverb_tail:
                while True:
                    # Pull audio from the effect until there's nothing left:
                    effected_chunk = reverb.process(
                        np.zeros((BUFFER_SIZE_SAMPLES, input_file.channels), np.float32),
                        sample_rate=input_file.samplerate,
                        reset=False,
                    )
                    if np.amax(np.abs(effected_chunk)) < NOISE_FLOOR:
                        break
                    output_file.write(effected_chunk)
    sys.stderr.write("Done!\n")

"""

#if __name__ == "__main__":
#    add_reverb(input_file="output_old.mp3", output_file="new_output.wav")