from websockets.server import serve
import asyncio

async def echo(websocket):
    message = await websocket.recv()
    print(f"Received: {message}")
    await websocket.send(message)
    await websocket.close()

async def main():
    port = 8001
    async with serve(echo, "0.0.0.0", port, compression=None):
        print(f"Server started at port {port}")
        await asyncio.Future()  # run forever

if __name__ == '__main__':
    asyncio.run(main())
