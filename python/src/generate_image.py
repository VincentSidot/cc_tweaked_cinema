from PIL import Image
from io import BytesIO
import numpy as np
import requests
import argparse


def convert_to_black_and_white(image, threshold=200):
    image = image.convert('L')
    image = np.array(image)
    image[image < threshold] = 0
    image[image >= threshold] = 255
    return Image.fromarray(image)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', type=str, required=True, help='url of the image')
    parser.add_argument('--output', type=str, required=True, help='output file name')
    parser.add_argument('--width', type=int, required=True, help='width of the output image')
    parser.add_argument('--height', type=int, required=True, help='height of the output image')
    parser.add_argument('--threshold', type=int, default=200, help='threshold for black and white image')
    parser.add_argument('--png', type=str, help="output png image (for debugging)", default=None)
    parser.add_argument('--color', action='store_true', help='change image to color image', default=False)
    return parser.parse_args()


def get_image(url):
    response = requests.get(url)
    image = Image.open(BytesIO(response.content))
    return image


def generate_dummy_image(image, output, width, height, threshold, png=None):
    image = image.resize((width, height), Image.LANCZOS)
    # black and white image
    image = convert_to_black_and_white(image, threshold)
    if png is not None:
        image.save(png)
    # export image with the given format
    # byte 1 is width, byte 2 is height
    # then the rest is the image data each byte encode 8 pixels
    # last byte is padded with 0 to make it 8 bits
    image_data = BytesIO()
    image_data.write(chr(width).encode('ascii'))
    image_data.write(chr(height).encode('ascii'))
    bits = []
    for i in range(height):
        for j in range(width):
            pixel = image.getpixel((j, i))
            if pixel == 0:
                bits.append('1')
            else:
                bits.append('0')
    while len(bits) % 8 != 0:
        bits.append('0')
    for i in range(0, len(bits), 8):
        byte = bits[i:i+8]
        byte = ''.join(byte)
        image_data.write(chr(int(byte, 2)).encode('ascii'))
    with open(output, 'wb') as f:
        f.write(image_data.getvalue())


def generate_palette(image):
    palette = image.palette.palette
    ret = []
    for i in range(0, len(palette), 3):
        ret.append((palette[i], palette[i+1], palette[i+2]))
    return ret[:16]


def generate_color_image(image, output, width, height, png=None):
    image = image.resize((width, height), Image.LANCZOS)
    image = image.convert(mode='P', palette=Image.ADAPTIVE, colors=16)
    palette = generate_palette(image)
    if png is not None:
        image.save(png)
    # export image with the given format
    # byte 1 is width, byte 2 is height
    # first 16*3 bytes is the palette (each 3 bytes encode a color)
    # then the rest is the image data each byte encode two pixels (4 bits each)
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
    with open(output, 'w') as f:
        f.write(image_data)
    return image_data


def generate_image_bytes(image, width, height, png=None):
    image = image.resize((width, height), Image.LANCZOS)
    image = image.convert(mode='P', palette=Image.ADAPTIVE, colors=16)
    palette = generate_palette(image)
    if png is not None:
        image.save(png)
    # export image with the given format
    # byte 1 is width, byte 2 is height
    # first 16*3 bytes is the palette (each 3 bytes encode a color)
    # then the rest is the image data each byte encode two pixels (4 bits each)
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
    while len(bits) % 8 != 0:
        bits.append('0000')
    for i in range(0, len(bits), 2):
        byte = bits[i:i+2]
        byte = ''.join(byte)
        image_data += chr(int(byte, 2))
    return image_data


def main():
    args = parse_args()
    image = get_image(args.url)
    if args.color:
        generate_color_image(image, args.output, args.width, args.height, args.png)
    else:
        generate_dummy_image(image, args.output, args.width, args.height, args.threshold, args.png)

if __name__ == '__main__':
    main()
