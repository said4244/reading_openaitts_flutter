#!/usr/bin/env python3
"""
Script to verify LiveKit agent can connect to the room
"""

import os
import sys
import asyncio
import json
from dotenv import load_dotenv
import aiohttp

# Load environment variables
load_dotenv()

async def check_livekit_connection():
    """Check if we can connect to LiveKit"""
    api_key = os.getenv("LIVEKIT_API_KEY")
    api_secret = os.getenv("LIVEKIT_API_SECRET")
    livekit_url = os.getenv("LIVEKIT_URL", "wss://cloud.livekit.io")
    
    print("="*60)
    print("LIVEKIT CONNECTION CHECK")
    print("="*60)
    
    print(f"API Key present: {'✓' if api_key else '✗'}")
    print(f"API Secret present: {'✓' if api_secret else '✗'}")
    print(f"LiveKit URL: {livekit_url}")
    
    if not api_key or not api_secret:
        print("\n❌ ERROR: Missing LiveKit credentials!")
        print("Make sure your .env file contains:")
        print("  LIVEKIT_API_KEY=your_key_here")
        print("  LIVEKIT_API_SECRET=your_secret_here")
        return False
    
    # Test token generation
    print("\nTesting token generation...")
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(
                "http://localhost:8080/token",
                params={
                    "room": "tts-reading-room13",
                    "identity": "test-agent13"
                }
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    print("✓ Token generated successfully")
                    print(f"  Room: {data.get('room')}")
                    print(f"  URL: {data.get('url')}")
                else:
                    print(f"✗ Token generation failed: {response.status}")
                    text = await response.text()
                    print(f"  Response: {text}")
                    return False
        except Exception as e:
            print(f"✗ Failed to connect to token server: {e}")
            print("  Make sure token_server.py is running on port 8080")
            return False
    
    return True

async def test_room_join():
    """Test joining a room with LiveKit SDK"""
    try:
        from livekit import api, rtc
        
        print("\n✓ LiveKit SDK imported successfully")
        
        # Get token
        async with aiohttp.ClientSession() as session:
            async with session.get(
                "http://localhost:8080/token",
                params={
                    "room": "tts-reading-room",
                    "identity": "python-test-client"
                }
            ) as response:
                if response.status != 200:
                    print("✗ Failed to get token")
                    return False
                
                token_data = await response.json()
                token = token_data['accessToken']
                url = token_data['url']
        
        print(f"\nAttempting to connect to room...")
        print(f"  URL: {url}")
        print(f"  Room: tts-reading-room")
        
        # Create room instance
        room = rtc.Room()
        
        # Try to connect
        await room.connect(url, token)
        
        print("✓ Successfully connected to room!")
        print(f"  Local participant: {room.local_participant.identity}")
        print(f"  Room name: {room.name}")
        print(f"  Remote participants: {len(room.remote_participants)}")
        
        # Wait a bit to see if anyone else is in the room
        await asyncio.sleep(2)
        
        print(f"\nAfter 2 seconds:")
        print(f"  Remote participants: {len(room.remote_participants)}")
        for participant in room.remote_participants.values():
            print(f"    - {participant.identity}")
        
        await room.disconnect()
        print("\n✓ Test completed successfully")
        return True
        
    except ImportError:
        print("\n✗ LiveKit SDK not found!")
        print("  Run: pip install livekit livekit-agents")
        return False
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

async def main():
    """Run all checks"""
    print("Starting LiveKit connection verification...\n")
    
    # Check basic connection
    if not await check_livekit_connection():
        print("\n❌ Basic connection check failed!")
        return
    
    # Test room join
    if not await test_room_join():
        print("\n❌ Room join test failed!")
        return
    
    print("\n✅ All checks passed!")
    print("\nNow let's check why the TTS agent isn't connecting...")
    print("\nMake sure you're running the agent with:")
    print("  python tts_agent.py dev")
    print("\nOr try:")
    print("  python tts_agent.py start")
    print("\nThe agent should show its identity when it connects.")

if __name__ == "__main__":
    asyncio.run(main())