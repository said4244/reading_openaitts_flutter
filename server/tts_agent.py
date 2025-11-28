"""
Simple TTS Agent using LiveKit's OpenAI plugin
With proper connection handling and cleanup
"""

import asyncio
import json
import logging
import os
import signal
import sys
import time
from typing import Optional
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from livekit import agents, rtc
from livekit.agents import JobContext, WorkerOptions, cli
from livekit.plugins import openai
import threading

# Load environment variables
load_dotenv()

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global shutdown flag and event
shutdown_requested = False
shutdown_event = asyncio.Event()

def signal_handler(signum, frame):
    """Handle shutdown signals forcefully"""
    global shutdown_requested
    logger.info(f"\n\nReceived signal {signum}, forcing shutdown...")
    shutdown_requested = True
    shutdown_event.set()
    
    # Force exit after 2 seconds if graceful shutdown fails
    def force_exit():
        logger.error("Force exiting...")
        os._exit(1)
    
    timer = threading.Timer(2.0, force_exit)
    timer.daemon = True
    timer.start()

# Register signal handlers
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


async def entrypoint(ctx: JobContext):
    """Main entry point for the TTS agent with proper cleanup"""
    
    logger.info("="*60)
    logger.info("TTS AGENT WITH AUDIO STARTING")
    logger.info(f"Room: {ctx.room.name}")
    logger.info("="*60)
    
    tts = None
    heartbeat_task = None
    
    try:
        # Connect to room with timeout
        logger.info("Connecting to room...")
        try:
            await asyncio.wait_for(
                ctx.connect(auto_subscribe=True),
                timeout=10.0
            )
        except asyncio.TimeoutError:
            logger.error("Connection timeout - failed to connect within 10 seconds")
            return
        
        logger.info("✅ Connected to room")
        logger.info(f"Local participant: {ctx.room.local_participant.identity}")
        logger.info(f"Local participant SID: {ctx.room.local_participant.sid}")
        
        # Initialize TTS
        tts = openai.TTS(
            model="gpt-4o-mini-tts",  # Change from "tts-1" to "tts-1-hd"
            voice="alloy",      # Change from "alloy" to "nova" for better Arabic
            instructions="Speak clearly with proper Arabic pronunciation at a slow pace suitable for language learning for kids. Remember to speak in a tajweed and tarteel mode. Remember to use the syrian accent. Remember to emphasize the vowels and harakt clearly, and sometimes even overexggerate them to make it easier for kids to learn. Use a friendly and engaging tone. Always follow the vowels and do not skip them even if its the last letter of a sentence or word. Speak in a consistent flow, avoid sounding robotic, sound alive and natural and emotional.",
        )
        logger.info("✅ TTS initialized")
        
        # Set up event handlers
        @ctx.room.on("disconnected")
        def on_disconnected(reason: str):
            logger.warning(f"Disconnected from room: {reason}")
            shutdown_event.set()
        
        @ctx.room.on("connection_quality_changed")
        def on_connection_quality_changed(participant: rtc.Participant, quality: rtc.ConnectionQuality):
            if participant == ctx.room.local_participant:
                logger.info(f"Connection quality: {quality}")
        
        @ctx.room.on("data_received")
        def on_data_received(data_packet: rtc.DataPacket):
            asyncio.create_task(handle_tts_request(ctx, data_packet, tts))
        
        # Send ready message
        ready_msg = json.dumps({
            "type": "agent_ready",
            "agent": "tts-agent-audio",
            "status": "ready",
            "timestamp": time.time()
        })
        await ctx.room.local_participant.publish_data(
            ready_msg.encode('utf-8'),
            reliable=True
        )
        logger.info("✅ Agent ready")
        
        # Start heartbeat task
        heartbeat_task = asyncio.create_task(send_heartbeat(ctx))
        
        while not shutdown_event.is_set() and not shutdown_requested:
            if ctx.room.connection_state != rtc.ConnectionState.CONN_CONNECTED:
                logger.error(f"Connection lost! State: {ctx.room.connection_state}")
                break
            
            # Check for shutdown every second
            await asyncio.sleep(1)
            
            if shutdown_requested:
                logger.info("Shutdown requested, breaking main loop")
                break
                
    except Exception as e:
        logger.error(f"Agent error: {e}", exc_info=True)
    finally:
        logger.info("Starting cleanup...")
        
        # Cancel heartbeat task
        if heartbeat_task and not heartbeat_task.done():
            heartbeat_task.cancel()
            try:
                await heartbeat_task
            except asyncio.CancelledError:
                pass
        
        # Send goodbye message
        try:
            if ctx.room.connection_state == rtc.ConnectionState.CONN_CONNECTED:
                goodbye_msg = json.dumps({
                    "type": "agent_disconnecting",
                    "agent": "tts-agent-audio",
                    "timestamp": time.time()
                })
                await ctx.room.local_participant.publish_data(
                    goodbye_msg.encode('utf-8'),
                    reliable=True
                )
                # Give the message time to send
                await asyncio.sleep(0.5)
        except Exception as e:
            logger.error(f"Error sending goodbye message: {e}")
        
        # Disconnect from room
        try:
            await ctx.room.disconnect()
            logger.info("✅ Disconnected from room")
        except Exception as e:
            logger.error(f"Error disconnecting: {e}")
        
        logger.info("Agent shutdown complete")


async def send_heartbeat(ctx: JobContext):
    """Send periodic heartbeat messages"""
    try:
        while not shutdown_event.is_set():
            if ctx.room.connection_state == rtc.ConnectionState.CONN_CONNECTED:
                heartbeat = json.dumps({
                    "type": "agent_heartbeat",
                    "timestamp": time.time(),
                    "participants": len(ctx.room.remote_participants)
                })
                await ctx.room.local_participant.publish_data(
                    heartbeat.encode('utf-8'),
                    reliable=False  # Don't need reliability for heartbeats
                )
            await asyncio.sleep(30)  # Heartbeat every 30 seconds
    except asyncio.CancelledError:
        logger.debug("Heartbeat task cancelled")
    except Exception as e:
        logger.error(f"Heartbeat error: {e}")


async def handle_tts_request(ctx: JobContext, data_packet: rtc.DataPacket, tts: openai.TTS):
    """Handle TTS requests and stream audio"""
    track = None
    publication = None
    
    try:
        message = json.loads(data_packet.data.decode('utf-8'))
        
        if message.get('type') != 'tts_request':
            return
            
        text = message.get('text', '')
        if not text:
            return
            
        logger.info(f"TTS request: '{text}'")
        
        # Get the requested voice or use default
        voice = message.get('voice', 'alloy')
        
        # Update TTS voice if different
        if tts._opts.voice != voice:
            tts._opts.voice = voice
            logger.info(f"Changed voice to: {voice}")
        
        # Create audio source with TTS properties
        logger.info(f"TTS properties - Sample rate: {tts.sample_rate}, Channels: {tts.num_channels}")
        audio_source = rtc.AudioSource(
            sample_rate=tts.sample_rate,
            num_channels=tts.num_channels
        )
        
        # Create and publish audio track
        track = rtc.LocalAudioTrack.create_audio_track(
            "tts-audio",
            audio_source
        )
        
        publication = await ctx.room.local_participant.publish_track(track)
        logger.info("✅ Published audio track")
        
        # Synthesize and stream TTS audio
        logger.info("Synthesizing TTS audio...")
        frame_count = 0
        async for audio_event in tts.synthesize(text):
            if shutdown_event.is_set() or shutdown_requested:
                logger.warning("Shutdown requested, stopping audio stream")
                break
            
            # Log first frame properties for debugging
            if frame_count == 0:
                frame = audio_event.frame
                logger.info(f"First audio frame properties - Sample rate: {frame.sample_rate}, Channels: {frame.num_channels}, Samples per channel: {frame.samples_per_channel}")
            
            frame_count += 1
            # Each audio_event contains a frame
            await audio_source.capture_frame(audio_event.frame)
        
        logger.info("✅ TTS streaming completed")
        
        # Send completion message
        completion_msg = json.dumps({
            'type': 'tts_complete',
            'text': text,
            'status': 'success',
            'timestamp': time.time()
        })
        await ctx.room.local_participant.publish_data(
            completion_msg.encode('utf-8'),
            reliable=True
        )
        
        # Wait a bit before unpublishing
        await asyncio.sleep(0.5)
        
    except Exception as e:
        logger.error(f"Error in TTS handler: {e}", exc_info=True)
        
        # Send error message
        try:
            error_msg = json.dumps({
                'type': 'tts_complete',
                'text': message.get('text', ''),
                'status': 'error',
                'error': str(e),
                'timestamp': time.time()
            })
            await ctx.room.local_participant.publish_data(
                error_msg.encode('utf-8'),
                reliable=True
            )
        except:
            pass
    finally:
        # Clean up track
        if publication and ctx.room.connection_state == rtc.ConnectionState.CONN_CONNECTED:
            try:
                # Add delay to ensure audio finishes playing
                await asyncio.sleep(1.5)  # Increase from 0.5 to 1.5 seconds
                await ctx.room.local_participant.unpublish_track(publication.sid)
                logger.info("Unpublished audio track")
            except Exception as e:
                logger.error(f"Error unpublishing track: {e}")


def main():
    """Main function"""
    # Check environment
    if not os.getenv("OPENAI_API_KEY"):
        logger.error("❌ OPENAI_API_KEY not set!")
        exit(1)
        
    if not os.getenv("LIVEKIT_API_KEY"):
        logger.error("❌ LiveKit credentials not set!")
        exit(1)
    
    # Add timestamp to agent identity to avoid conflicts
    agent_id_suffix = int(time.time()) % 10000  # Last 4 digits of timestamp
    
    logger.info(f"Starting TTS Agent with Audio (ID suffix: {agent_id_suffix})...")
    
    # Configure worker with proper options
    worker_options = WorkerOptions(
        entrypoint_fnc=entrypoint,
        # Set max_retry to handle temporary connection issues
        max_retry=3,
    )
    
    try:
        # Run agent
        cli.run_app(worker_options)
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
    finally:
        logger.info("Agent process ending")


if __name__ == "__main__":
    main()