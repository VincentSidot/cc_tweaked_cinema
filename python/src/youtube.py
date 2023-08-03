import asyncio
import cv2
import subprocess
import random
import argparse
import os
import numpy as np
from websockets.server import serve
from pytube import YouTube
from PIL import Image
from time import time
from pydub import AudioSegment


def parse_args():
    def folder(string):
        # ensure folder is a folder
        # ensure folder is readable and writable

        # if folder does not exist, create it
        try:
            if not os.path.isdir(string):
                os.mkdir(string)
        except OSError:
            raise argparse.ArgumentTypeError(f"{string} is not a folder")

        # ensure folder is readable and writable
        if not os.access(string, os.R_OK | os.W_OK):
            raise argparse.ArgumentTypeError(
                    f"{string} is not readable and writable"
                )

        return string

    arg = argparse.ArgumentParser()
    arg.add_argument(
        "download_folder",
        help="Folder to download the video to",
        type=folder,
        default="/home/sidotv/dev/computercraft/cinema/download/"
    )
    arg.add_argument(
        "--port",
        help="Port to listen on",
        type=int,
        default=8001
    )
    return arg.parse_args()


def download_video(url, base_folder="."):
    """
    Download the video from the given url and save it to the given output
    Download the video with the lowest resolution
    """
    folder_path = base_folder
    video_name = "video.mp4"
    audio_name = "audio.mp3"
    video_path = f"{folder_path}/{video_name}"
    audio_path = f"{folder_path}/{audio_name}"
    # check if the files exists
    # if the files exists, do not download
    if os.path.isfile(video_path) and \
            os.path.isfile(audio_path):
        print(f"Video already downloaded to {folder_path}")
        return video_path, audio_path
    yt = YouTube(url)
    yt.streams.filter(
            progressive=True,
            file_extension='mp4'
        ).order_by(
            'resolution'
        ).desc().last().download(
            folder_path,
            filename=video_name
        )
    subprocess.call([
        "ffmpeg",
        "-y",
        "-i",
        video_path,
        "-b:a",
        "48k",
        "-ar",
        "48000",
        "-vn",
        audio_path,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.STDOUT
    )
    print(f"Video downloaded to {folder_path}")
    return video_path, audio_path


def get_video_id_from_url(url):
    return url.split("=")[-1].split("&")[0]


class ImageEncoder:

    def __init__(self, image):
        self.image = image

    def __generate_palette__(self, image):
        palette = image.palette.palette
        ret = []
        for i in range(0, len(palette), 3):
            ret.append((palette[i], palette[i+1], palette[i+2]))
        return ret[:16]

    def encode(self, width, height):
        image = self.image.resize((width, height), Image.LANCZOS)
        image = image.convert(mode='P', palette=Image.ADAPTIVE, colors=16)
        palette = self.__generate_palette__(image)
        # export image with the given format
        # byte 1 is width, byte 2 is height
        # first 16*3 bytes is the palette (each 3 bytes encode a color)
        # then the rest is the image data
        # each byte encode two pixels (4 bits each)
        # half byte encode the color of the pixel
        # last byte is padded with 0 to make it 8 bits
        image_data = ""
        image_data += chr(width)
        image_data += chr(height)
        for color in palette:
            for i in range(3):
                image_data += chr(color[i])
        bits = []
        for i in range(height):
            for j in range(width):
                pixel = image.getpixel((j, i))
                bits.append(format(pixel, '04b'))
        while len(bits) % 2 != 0:
            bits.append('0000')
        for i in range(0, len(bits), 2):
            byte = bits[i:i+2]
            byte = ''.join(byte)
            image_data += chr(int(byte, 2))
        return image_data


class VideoEncoder:
    def __init__(self, video_path):
        self.video_path = video_path
        self.last_frame_time = None
        self.frame_remainder = 0.0

    def start(self):
        self.cap = cv2.VideoCapture(self.video_path)
        self.fps = self.cap.get(cv2.CAP_PROP_FPS)
        return self.fps

    def estimate_frame_to_skip(self):
        if self.last_frame_time is None:
            # first frame so no need to skip
            self.last_frame_time = time()
            return 0
        new_time = time()
        elapsed_time = new_time - self.last_frame_time
        self.last_frame_time = new_time
        frame_to_skip_float = elapsed_time * self.fps - 1
        # -1 to account the fact one frame is already read
        frame_to_skip_int = int(frame_to_skip_float)
        self.frame_remainder += frame_to_skip_float - frame_to_skip_int
        if self.frame_remainder >= 1:
            frame_to_skip_int += 1
            self.frame_remainder -= 1
        return frame_to_skip_int

    def get_next_frame(self, width, height, ignored_frames=None):
        if ignored_frames is None:
            ignored_frames = self.estimate_frame_to_skip()
        begin_time = time()
        if self.cap is None:
            raise Exception("Encoder not started")
        for _ in range(ignored_frames):
            self.cap.read()
        ret, frame = self.cap.read()
        if not ret:
            return None, 0, 0
        image = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        image_encoded = ImageEncoder(image).encode(width, height)
        end_time = time()
        return image_encoded, (end_time - begin_time)*1000, ignored_frames
        # return the time it takes to generate the frame (in milliseconds)

    def stop(self):
        self.cap.release()


class AudioEncoder:
    def __init__(self, audio_path):
        self.audio_path = audio_path
        download_folder = os.path.dirname(audio_path)
        self.output_left_path = f"{download_folder}/output_left.dfpwm"
        self.output_right_path = f"{download_folder}/output_right.dfpwm"
        if os.path.isfile(self.output_left_path):
            os.remove(self.output_left_path)
        if os.path.isfile(self.output_right_path):
            os.remove(self.output_right_path)
        if os.path.isfile(self.output_left_path) and os.path.isfile(self.output_right_path):
            print("Audio already encoded")
        else:
            begin_time = time()
            subprocess.call([
                "./bin/dfpwm_encoder",
                self.audio_path,
                self.output_left_path,
                self.output_right_path,
            ], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
            end_time = time()
            print(f"Audio encoded in {end_time - begin_time} seconds")

    def frame_generator(self, sample_size, side):
        if side == "left":
            path = self.output_left_path
        else:
            path = self.output_right_path
        with open(path, "rb") as f:
            while True:
                data = f.read(sample_size)
                if len(data) == 0:
                    break
                yield data

# class AudioEncoder:
#     SAMPLE_RATE = 48000
#     PREC = 10
#
#     def __init__(self, audio_path):
#         self.audio_path = audio_path
#
#     async def encode_dfpwm(self, input_data, sample_size, queue):
#         charge = 0
#         strength = 0
#         previous_bit = False
#         out_length = len(input_data) // 8
#
#         out = np.zeros(sample_size, dtype=np.uint8)
#
#         PREC = self.PREC
#         PREC_MINUS_8 = PREC - 8
#         ONE_SHIFT_PREC_THEN_MINUS_1 = (1 << PREC) - 1
#         ONE_SHIFT_PREC_MINUS_1 = 1 << (PREC - 1)
#
#         for i in range(out_length):
#             this_byte = 0
#
#             for j in range(8):
#                 level = int(input_data[i * 8 + j] * 127)
#
#                 current_bit = (level > charge) or (level == charge and charge == 127)
#                 target = 127 if current_bit else -128
#
#                 next_charge = charge + ((strength * (target - charge) + ONE_SHIFT_PREC_MINUS_1) >> PREC)
#                 if next_charge == charge and next_charge != target:
#                     next_charge += 1 if current_bit else -1
#
#                 z = ONE_SHIFT_PREC_THEN_MINUS_1 if current_bit == previous_bit else 0
#                 next_strength = strength
#                 if strength != z:
#                     next_strength += 1 if current_bit == previous_bit else -1
#                 if next_strength < 2 << PREC_MINUS_8:
#                     next_strength = 2 << PREC_MINUS_8
#
#                 charge = next_charge
#                 strength = next_strength
#                 previous_bit = current_bit
#
#                 this_byte = (this_byte >> 1) + 128 if current_bit else this_byte >> 1
#             out[i % sample_size] = this_byte
#             if i % sample_size == sample_size-1:
#                 await queue.put(out)
#
#     @staticmethod
#     def pydub_to_np(audio):
#         """
#         Converts pydub audio segment into np.float32 of shape [duration_in_seconds*sample_rate, channels],
#         where each value is in range [-1.0, 1.0].
#         Returns tuple audio_np_array.
#         """
#         channel_sounds = audio.split_to_mono()
#         samples = [s.get_array_of_samples() for s in channel_sounds]
#         fp_arr = np.array(samples).T.astype(np.float32)
#         fp_arr /= np.iinfo(samples[0].typecode).max
#         return fp_arr
#
#     async def get_next_sample(self, side):
#         if side == "left":
#             return await self.left_encoded_queue.get()
#
#         elif side == "right":
#             return await self.right_encoded_queue.get()
#         else:
#             raise Exception("Invalid side")
#
#     async def convert_audio(self, sample_size):
#         input_audio = AudioSegment.from_file(self.audio_path, format="mp3")
#         input_audio = input_audio.set_frame_rate(self.SAMPLE_RATE)
#         input_data = AudioEncoder.pydub_to_np(input_audio)
#         left_channel = input_data[:, 0]
#         right_channel = input_data[:, 1]
#         # self.left_encoded_queue = asyncio.Queue()
#         # self.task_left = asyncio.create_task(
#         #     self.encode_dfpwm(
#         #         left_channel,
#         #         sample_size,
#         #         self.left_encoded_queue
#         #     )
#         # )
#         self.right_encoded_queue = asyncio.Queue(maxsize=1)
#         self.task_right = asyncio.create_task(
#             self.encode_dfpwm(
#                 right_channel,
#                 sample_size,
#                 self.right_encoded_queue
#             )
#         )
#
#     async def has_next_sample(self):
#         right_task_done = self.task_right.done() if hasattr(self, "task_right") else True
#         right_task_queue_empty = self.right_encoded_queue.empty() if hasattr(self, "right_encoded_queue") else True
#         left_task_done = self.task_left.done() if hasattr(self, "task_left") else True
#         left_task_queue_empty = self.left_encoded_queue.empty() if hasattr(self, "left_encoded_queue") else True
#         return not (right_task_done and right_task_queue_empty and left_task_done and left_task_queue_empty)
#

class WebsocketServer:
    __alphabet__ = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    def __init__(self, host, port, download_folder):
        self.download_folder = download_folder
        self.host = host
        self.port = port
        self.clients = {}

    async def start(self):
        async with serve(self.handler, self.host, self.port, compression=None):
            print(f"Server started at {self.host}:{self.port}")
            await asyncio.Future()  # run forever

    def __gen_client_id__(self):
        # generate a random string (10)
        client_id = ''.join(random.choices(self.__alphabet__, k=10))
        if client_id in self.clients:
            return self.__gen_client_id__()
        return client_id

    async def handler(self, websocket, path):
        print(f"New connection: {websocket.remote_address[0]}:{websocket.remote_address[1]}{path}")

        if path == "/":
            await websocket.send(
                    "You should connect to /new to get a client id"
            )
            await websocket.close()
            return
        elif path == "/new":
            await self.new_client(websocket)
        else:
            try:
                params = path.split('/')[1:]
                client_id = params[0]
                mode = params[1]
            except ValueError:
                await websocket.close()
                return
            else:
                if client_id not in self.clients:
                    print(f"Client {client_id} not found")
                    await websocket.close()
                    return
                client = self.clients[client_id]
                if mode == "video":
                    if client["video"] is not None:
                        print(f"Client {client_id} already has a video socket")
                        await websocket.close()
                        return
                    client["client"].video = True
                    await client["client"].video_websocket(
                            websocket)
                    client["video"] = None
                elif mode == "audio":
                    if client["audio"] is not None:
                        print(f"Client {client_id} already has a audio socket")
                        await websocket.close()
                        return
                    client["client"].audio = True
                    side = params[2]
                    await client["client"].audio_websocket(
                            websocket, side)
                    client["audio"] = None

    async def new_client(self, websocket):
        print("New client connected...")
        raw_url = await websocket.recv()
        video_url = raw_url.strip()
        client_id = self.__gen_client_id__()
        # client_id = get_video_id_from_url(video_url)
        client = WebsocketClient(
                client_id,
                self.download_folder
        )
        self.clients[client_id] = {
            "client": client,
            "video": None,
            "audio": None
        }
        client.handle(video_url)
        await websocket.send(client_id)
        await websocket.close()
        print(f"Client '{client_id}' created")


class WebsocketClient:
    def __init__(
            self,
            client_id,
            download_folder="../../download/"):
        print("Client connected...")
        self.client_id = client_id
        self.download_folder = download_folder

    def handle(self, video_url):
        print("Waiting for video url...")
        print("Received url:", video_url)

        # check if the folder client_id exists in the download folder
        # if not, create it
        # if yes check if video.mp4 and audio.mp3 exist
        # if no delete the folder and create it
        # if yes do nothing
        client_folder = os.path.join(self.download_folder, get_video_id_from_url(video_url))
        if not os.path.exists(client_folder):
            os.mkdir(client_folder)
        self.video_path, self.audio_path = download_video(
                video_url, client_folder)
        print("Video downloaded")
        print("Starting video and audio encoding...")
        self.video_encoder = VideoEncoder(self.video_path)
        self.audio_encoder = AudioEncoder(self.audio_path)

    async def video_websocket(self, websocket):
        # first message is the size of the image
        size = await websocket.recv()
        width, height = [int(x.strip()) for x in size.split('x')]
        print("Received size:", width, height)
        fps = self.video_encoder.start()
        print(f"Video is encoded at {fps} fps")
        while True:
            image_encoded, elapsed_time, ignored_frames = self.video_encoder.get_next_frame(
                    width,
                    height
                )
            if image_encoded is None:
                break
            print(f"Frame generated in {elapsed_time}ms")
            print(f"Ignored {ignored_frames} frames")
            await websocket.send(image_encoded)
            response = await websocket.recv()
            width, height = [int(x.strip()) for x in response.split('x')]
        print("Finished sending frames")
        await websocket.send("stop")
        await websocket.close()

    async def audio_websocket(self, websocket, side):
        # itialize the client socket
        # send to the client the size of the frame packets
        # (1s of audio per packets)
        sample_size = 16 * 1024
        await websocket.send(str(sample_size))
        for data in self.audio_encoder.frame_generator(sample_size, side):
            await websocket.send(data)
            await websocket.recv()
        # for audio_data in audio_data_generator:
        #     # send the audio data to the client
        #     await websocket.send(audio_data.tobytes())
        #     # wait client to be ready for the next packet
        #     await websocket.recv()


async def main(args):
    port = args.port
    host = "0.0.0.0"
    server = WebsocketServer(host, port, args.download_folder)
    await server.start()


if __name__ == '__main__':
    args = parse_args()
    asyncio.run(main(args))
