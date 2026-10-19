# Two iPhones on the same Wi-Fi

Install the same multiplayer build on both iPhones. Only Player 1 needs the cartridge. There is no account, internet server, cellular route or ROM download on Player 2's phone.

[Download the verified multiplayer IPA and matching source](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39185044963/artifacts/12157618280), then re-sign/install using [BUILD_WINDOWS.md](BUILD_WINDOWS.md). [Build #5 passed](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39185044963); its [verification record](evidence/multiplayer-build.json) distinguishes hosted tests from the pending two-phone acceptance.

## Host and join

1. Connect both phones to the same Wi-Fi and allow **Local Network** and **Camera** access when prompted. Guest networks with client isolation can prevent discovery or connections.
2. Player 1 opens a cartridge, uses **Free AR**, scans a textured table and taps to place the diorama. Open the game menu (**…**) → **Local multiplayer** → **Host current cartridge**.
3. Give the displayed eight-character room code to Player 2. On their library screen, choose **Local multiplayer · join as Player 2**, enter the code and tap **Join as Player 2**. Player 2 does not import a ROM.
4. The host scans around the table until the table-map status says it was sent. Player 2 aims at the same area and moves slowly until the shared anchor aligns. Both people can then walk around the same world independently.
5. Player 1 controls the first joystick; Player 2 controls the second. Each phone has its own joystick and Fire, or a paddle slider and Fire when the host selected paddles before opening the room. A locally paired gamepad controls that phone's assigned player.
6. On the host, select the cartridge's normal two-player variation with **SELECT / RESET**. This uses the Atari game's own multiplayer rules, including alternating turns where applicable.

The included Tabletop Test now supports two players: the red actor moves autonomously until Player 2 first moves or fires. It then stays under Player 2's control until Reset. The blue actor remains Player 1; each player's Fire plays its own original TIA tone. This is actual 6507 cartridge code.

## Shared placement and recovery

The host controls shared placement, world width, rotation, tilt and reconstructed geometry. Player 2 keeps their own physical camera, local lighting, volume and control layout. No camera video is mirrored. The original framebuffer comparison is also synchronized.

If alignment is slow, point Player 2's camera at the table and nearby textured objects the host already scanned. Use **Align shared table again** on the guest or **Share table again** on the host. Repositioning on the host hides the guest world until a new map is shared and aligned. A virtual inspection view is available on each phone, but it does not establish physical alignment.

The host can pause the game, operate console switches, save/load and reset. A guest pause suspends only their own controls/audio; the host can continue. Leaving a control releases it; input heartbeats repeat current state every 100 ms, and the host clears remote input after 500 ms without an update. A missing connection times out after eight seconds, pauses the host and lets Player 2 rejoin. A second guest cannot replace the connected player.

Leaving the app for the background closes its room connection. Return to the app and host/join again. Closing the room lets Player 1 continue alone. Player 2 returns to the library when the host disconnects. Local Network permission can be restored in iPhone Settings if it was denied.

## Implementation and verification boundaries

Bonjour advertises `_atari-ar._tcp` on Wi-Fi only. The discovery name is derived from the code; the code itself is not advertised. TLS 1.2 PSK with AES-128-GCM authenticates and encrypts the connection using the random room code. Apple's older Network.framework PSK API does not support TLS 1.3. The code is ephemeral and should only be shared with the intended second player.

The host alone runs Stella. It transmits bounded, compressed snapshots of object geometry, original pixels, original PCM audio, presentation settings and an ARWorldMap. It never transmits cartridge bytes or a save state. One scene is in flight at a time, with one latest replacement; skipped visual frames retain their audio up to a bounded latency budget. Secure ARWorldMap archives align the two AR coordinate systems, while each phone renders locally.

Hosted tests exercise actual encrypted loopback connections, wrong-code rejection, scene/audio serialization, fragmented TCP, malformed packets, guest input restrictions, bounded frame queues, extra-peer rejection and disconnect/rejoin. These tests do not establish real Wi-Fi discovery, physical AR alignment, device latency or audio quality. The two-phone checks in [DEVICE_TESTING.md](DEVICE_TESTING.md) must still be executed.

Apple references: [Network framework's peer-to-peer protocol sample](https://developer.apple.com/documentation/network/building-a-custom-peer-to-peer-protocol), [network security and PSK limitations](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework), and [multiuser AR world-map sharing](https://developer.apple.com/documentation/arkit/creating-a-multiuser-ar-experience).
