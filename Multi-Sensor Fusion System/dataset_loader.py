#!/usr/bin/env python3
"""
KITTI and nuScenes Dataset Loader for Multi-Sensor Fusion Testing
Real-time data streaming simulation for autonomous vehicle testing
"""

import os
import json
import time
import numpy as np
from pathlib import Path
import threading
from queue import Queue
import struct

class KITTIDatasetLoader:
    """KITTI Dataset Loader for real-time simulation"""
    
    def __init__(self, dataset_path="./datasets/kitti"):
        self.dataset_path = Path(dataset_path)
        self.sequences = []
        self.current_sequence = 0
        self.frame_queue = Queue(maxsize=100)
        self.is_streaming = False
        
    def load_sequence_info(self):
        """Load KITTI sequence information"""
        
        # KITTI sequences (simulated structure)
        self.sequences = [
            {
                'id': '00', 'name': 'Highway', 'frames': 4541, 'fps': 10,
                'description': 'Highway driving with overtaking maneuvers'
            },
            {
                'id': '01', 'name': 'City', 'frames': 1101, 'fps': 10,
                'description': 'City driving with traffic lights and pedestrians'
            },
            {
                'id': '02', 'name': 'Residential', 'frames': 4661, 'fps': 10,
                'description': 'Residential area with parked cars'
            },
            {
                'id': '03', 'name': 'Country', 'frames': 801, 'fps': 10,
                'description': 'Country road with curves'
            }
        ]
        
        print(f"📁 KITTI Dataset Loaded: {len(self.sequences)} sequences")
        for seq in self.sequences:
            print(f"  Sequence {seq['id']}: {seq['name']} ({seq['frames']} frames)")
    
    def generate_kitti_frame(self, sequence_id, frame_id):
        """Generate KITTI-like sensor data frame"""
        
        # Simulate KITTI data structure
        frame_data = {
            'sequence_id': sequence_id,
            'frame_id': frame_id,
            'timestamp': time.time(),
            
            # Camera data (stereo)
            'camera': {
                'left_image': self._generate_camera_data(1242, 375),  # KITTI image size
                'right_image': self._generate_camera_data(1242, 375),
                'calibration': self._get_kitti_camera_calibration(),
                'quality_score': np.random.uniform(0.7, 0.95)
            },
            
            # LiDAR data (Velodyne HDL-64E)
            'lidar': {
                'points': self._generate_lidar_points(100000),  # ~100k points
                'intensity': np.random.uniform(0.6, 0.9),
                'calibration': self._get_kitti_lidar_calibration()
            },
            
            # GPS/IMU data
            'gps_imu': {
                'position': [np.random.uniform(-1, 1) for _ in range(3)],
                'orientation': [np.random.uniform(-np.pi, np.pi) for _ in range(3)],
                'velocity': [np.random.uniform(-20, 20) for _ in range(3)],
                'accuracy': np.random.uniform(0.8, 0.95)
            },
            
            # Ground truth (for validation)
            'ground_truth': {
                'objects': self._generate_kitti_objects(),
                'ego_pose': self._generate_ego_pose()
            }
        }
        
        return frame_data
    
    def _generate_camera_data(self, width, height):
        """Generate simulated camera data"""
        # Simulate compressed image data
        return np.random.randint(0, 256, size=(height//8, width//8), dtype=np.uint8)
    
    def _generate_lidar_points(self, num_points):
        """Generate simulated LiDAR point cloud"""
        # Simulate point cloud: [x, y, z, intensity]
        points = np.random.uniform(-50, 50, size=(num_points//1000, 4))
        return points.astype(np.float32)
    
    def _get_kitti_camera_calibration(self):
        """KITTI camera calibration parameters"""
        return {
            'P0': np.eye(3, 4),  # Simplified
            'P1': np.eye(3, 4),
            'P2': np.eye(3, 4),
            'P3': np.eye(3, 4)
        }
    
    def _get_kitti_lidar_calibration(self):
        """KITTI LiDAR calibration parameters"""
        return {
            'Tr_velo_to_cam': np.eye(4),  # Simplified
            'R0_rect': np.eye(3)
        }
    
    def _generate_kitti_objects(self):
        """Generate KITTI-style object annotations"""
        objects = []
        num_objects = np.random.randint(0, 10)
        
        for i in range(num_objects):
            obj = {
                'type': np.random.choice(['Car', 'Pedestrian', 'Cyclist', 'Van']),
                'bbox': [np.random.uniform(0, 1242) for _ in range(4)],
                'location': [np.random.uniform(-50, 50) for _ in range(3)],
                'rotation_y': np.random.uniform(-np.pi, np.pi)
            }
            objects.append(obj)
        
        return objects
    
    def _generate_ego_pose(self):
        """Generate ego vehicle pose"""
        return {
            'position': [np.random.uniform(-1000, 1000) for _ in range(3)],
            'rotation': [np.random.uniform(-np.pi, np.pi) for _ in range(3)]
        }

class NuScenesDatasetLoader:
    """nuScenes Dataset Loader for real-time simulation"""
    
    def __init__(self, dataset_path="./datasets/nuscenes"):
        self.dataset_path = Path(dataset_path)
        self.scenes = []
        self.current_scene = 0
        self.frame_queue = Queue(maxsize=100)
        self.is_streaming = False
        
    def load_scene_info(self):
        """Load nuScenes scene information"""
        
        # nuScenes scenes (simulated structure)
        self.scenes = [
            {
                'token': 'scene-0001', 'name': 'Boston Seaport Day',
                'location': 'boston-seaport', 'weather': 'clear', 'time': 'day',
                'frames': 390, 'fps': 2  # nuScenes is 2Hz
            },
            {
                'token': 'scene-0002', 'name': 'Boston Seaport Night',
                'location': 'boston-seaport', 'weather': 'clear', 'time': 'night',
                'frames': 390, 'fps': 2
            },
            {
                'token': 'scene-0003', 'name': 'Singapore Rain',
                'location': 'singapore-onenorth', 'weather': 'rain', 'time': 'day',
                'frames': 390, 'fps': 2
            },
            {
                'token': 'scene-0004', 'name': 'Singapore Night',
                'location': 'singapore-queenstown', 'weather': 'clear', 'time': 'night',
                'frames': 390, 'fps': 2
            }
        ]
        
        print(f"📁 nuScenes Dataset Loaded: {len(self.scenes)} scenes")
        for scene in self.scenes:
            print(f"  Scene {scene['token']}: {scene['name']} ({scene['frames']} frames)")
    
    def generate_nuscenes_frame(self, scene_token, frame_id):
        """Generate nuScenes-like sensor data frame"""
        
        scene = next(s for s in self.scenes if s['token'] == scene_token)
        
        frame_data = {
            'scene_token': scene_token,
            'frame_id': frame_id,
            'timestamp': time.time(),
            'location': scene['location'],
            'weather': scene['weather'],
            'time_of_day': scene['time'],
            
            # 6 cameras (360° coverage)
            'cameras': {
                'CAM_FRONT': self._generate_camera_data(1600, 900),
                'CAM_FRONT_LEFT': self._generate_camera_data(1600, 900),
                'CAM_FRONT_RIGHT': self._generate_camera_data(1600, 900),
                'CAM_BACK': self._generate_camera_data(1600, 900),
                'CAM_BACK_LEFT': self._generate_camera_data(1600, 900),
                'CAM_BACK_RIGHT': self._generate_camera_data(1600, 900),
                'quality_factor': self._get_quality_factor(scene)
            },
            
            # LiDAR (32-beam)
            'lidar': {
                'points': self._generate_lidar_points(34000),  # ~34k points
                'intensity': np.random.uniform(0.5, 0.8),
                'calibration': self._get_nuscenes_lidar_calibration()
            },
            
            # 5 Radars
            'radars': {
                'RADAR_FRONT': self._generate_radar_data(),
                'RADAR_FRONT_LEFT': self._generate_radar_data(),
                'RADAR_FRONT_RIGHT': self._generate_radar_data(),
                'RADAR_BACK_LEFT': self._generate_radar_data(),
                'RADAR_BACK_RIGHT': self._generate_radar_data()
            },
            
            # GPS/IMU
            'gps_imu': {
                'position': [np.random.uniform(-1, 1) for _ in range(3)],
                'orientation': [np.random.uniform(-np.pi, np.pi) for _ in range(4)],  # quaternion
                'velocity': [np.random.uniform(-15, 15) for _ in range(3)],
                'accuracy': self._get_gps_accuracy(scene['location'])
            },
            
            # Annotations
            'annotations': {
                'objects': self._generate_nuscenes_objects(),
                'ego_pose': self._generate_ego_pose()
            }
        }
        
        return frame_data
    
    def _generate_camera_data(self, width, height):
        """Generate simulated camera data"""
        return np.random.randint(0, 256, size=(height//10, width//10), dtype=np.uint8)
    
    def _generate_radar_data(self):
        """Generate simulated radar data"""
        return {
            'points': np.random.uniform(-100, 100, size=(50, 4)),  # [x, y, vx, vy]
            'quality': np.random.uniform(0.6, 0.9)
        }
    
    def _get_quality_factor(self, scene):
        """Get quality factor based on scene conditions"""
        base_quality = 0.8
        
        if scene['weather'] == 'rain':
            base_quality *= 0.6
        if scene['time'] == 'night':
            base_quality *= 0.7
            
        return base_quality
    
    def _get_gps_accuracy(self, location):
        """Get GPS accuracy based on location"""
        if 'singapore' in location:
            return np.random.uniform(0.6, 0.8)  # Urban GPS challenges
        else:
            return np.random.uniform(0.7, 0.9)  # Boston seaport
    
    def _get_nuscenes_lidar_calibration(self):
        """nuScenes LiDAR calibration"""
        return {
            'translation': [0, 0, 1.84],
            'rotation': [0, 0, 0, 1]  # quaternion
        }
    
    def _generate_nuscenes_objects(self):
        """Generate nuScenes-style annotations"""
        objects = []
        num_objects = np.random.randint(0, 15)  # More objects in urban
        
        categories = [
            'vehicle.car', 'vehicle.truck', 'vehicle.bus',
            'human.pedestrian.adult', 'vehicle.bicycle',
            'vehicle.motorcycle', 'movable_object.trafficcone'
        ]
        
        for i in range(num_objects):
            obj = {
                'category': np.random.choice(categories),
                'translation': [np.random.uniform(-50, 50) for _ in range(3)],
                'size': [np.random.uniform(1, 5) for _ in range(3)],
                'rotation': [np.random.uniform(-1, 1) for _ in range(4)],  # quaternion
                'velocity': [np.random.uniform(-10, 10) for _ in range(2)]
            }
            objects.append(obj)
        
        return objects
    
    def _generate_ego_pose(self):
        """Generate ego vehicle pose"""
        return {
            'translation': [np.random.uniform(-1000, 1000) for _ in range(3)],
            'rotation': [np.random.uniform(-1, 1) for _ in range(4)]  # quaternion
        }

class DatasetStreamer:
    """Real-time dataset streaming for testing"""
    
    def __init__(self):
        self.kitti_loader = KITTIDatasetLoader()
        self.nuscenes_loader = NuScenesDatasetLoader()
        self.streaming_thread = None
        self.stop_streaming = False
        
    def start_kitti_stream(self, sequence_id='00', fps=10):
        """Start KITTI dataset streaming"""
        
        print(f"🎬 Starting KITTI stream - Sequence {sequence_id} @ {fps} FPS")
        
        self.kitti_loader.load_sequence_info()
        self.stop_streaming = False
        
        def stream_worker():
            frame_id = 0
            frame_interval = 1.0 / fps
            
            while not self.stop_streaming:
                start_time = time.time()
                
                # Generate frame
                frame_data = self.kitti_loader.generate_kitti_frame(sequence_id, frame_id)
                
                # Convert to fusion system format
                fusion_input = self.convert_kitti_to_fusion_format(frame_data)
                
                # Put in queue for processing
                if not self.kitti_loader.frame_queue.full():
                    self.kitti_loader.frame_queue.put(fusion_input)
                
                frame_id += 1
                
                # Maintain frame rate
                elapsed = time.time() - start_time
                if elapsed < frame_interval:
                    time.sleep(frame_interval - elapsed)
        
        self.streaming_thread = threading.Thread(target=stream_worker)
        self.streaming_thread.start()
    
    def start_nuscenes_stream(self, scene_token='scene-0001', fps=2):
        """Start nuScenes dataset streaming"""
        
        print(f"🎬 Starting nuScenes stream - Scene {scene_token} @ {fps} FPS")
        
        self.nuscenes_loader.load_scene_info()
        self.stop_streaming = False
        
        def stream_worker():
            frame_id = 0
            frame_interval = 1.0 / fps
            
            while not self.stop_streaming:
                start_time = time.time()
                
                # Generate frame
                frame_data = self.nuscenes_loader.generate_nuscenes_frame(scene_token, frame_id)
                
                # Convert to fusion system format
                fusion_input = self.convert_nuscenes_to_fusion_format(frame_data)
                
                # Put in queue for processing
                if not self.nuscenes_loader.frame_queue.full():
                    self.nuscenes_loader.frame_queue.put(fusion_input)
                
                frame_id += 1
                
                # Maintain frame rate
                elapsed = time.time() - start_time
                if elapsed < frame_interval:
                    time.sleep(frame_interval - elapsed)
        
        self.streaming_thread = threading.Thread(target=stream_worker)
        self.streaming_thread.start()
    
    def convert_kitti_to_fusion_format(self, kitti_frame):
        """Convert KITTI frame to fusion system input format"""
        
        return {
            'camera_bitstream': self._pack_camera_data(kitti_frame['camera']),
            'lidar_compressed': self._pack_lidar_data(kitti_frame['lidar']),
            'radar_raw': self._pack_radar_data(kitti_frame.get('radar', {})),
            'imu_raw': self._pack_imu_data(kitti_frame['gps_imu']),
            'timestamp': int(kitti_frame['timestamp'] * 1000000),  # microseconds
            'metadata': {
                'sequence_id': kitti_frame['sequence_id'],
                'frame_id': kitti_frame['frame_id'],
                'dataset': 'KITTI'
            }
        }
    
    def convert_nuscenes_to_fusion_format(self, nuscenes_frame):
        """Convert nuScenes frame to fusion system input format"""
        
        return {
            'camera_bitstream': self._pack_camera_data(nuscenes_frame['cameras']),
            'lidar_compressed': self._pack_lidar_data(nuscenes_frame['lidar']),
            'radar_raw': self._pack_radar_data(nuscenes_frame['radars']),
            'imu_raw': self._pack_imu_data(nuscenes_frame['gps_imu']),
            'timestamp': int(nuscenes_frame['timestamp'] * 1000000),
            'metadata': {
                'scene_token': nuscenes_frame['scene_token'],
                'frame_id': nuscenes_frame['frame_id'],
                'dataset': 'nuScenes',
                'location': nuscenes_frame['location'],
                'weather': nuscenes_frame['weather']
            }
        }
    
    def _pack_camera_data(self, camera_data):
        """Pack camera data into bitstream format"""
        # Simulate packing camera data into 3072-bit format
        if isinstance(camera_data, dict) and 'left_image' in camera_data:
            # KITTI stereo
            data = camera_data['left_image'].flatten()[:384]  # 3072/8 = 384 bytes
        else:
            # nuScenes multi-camera - use front camera
            data = camera_data['CAM_FRONT'].flatten()[:384]
        
        # Pad to 384 bytes
        if len(data) < 384:
            data = np.pad(data, (0, 384 - len(data)), 'constant')
        
        return int.from_bytes(data.astype(np.uint8).tobytes(), 'big')
    
    def _pack_lidar_data(self, lidar_data):
        """Pack LiDAR data into compressed format"""
        points = lidar_data['points'].flatten()[:64]  # 512/8 = 64 bytes
        
        if len(points) < 64:
            points = np.pad(points, (0, 64 - len(points)), 'constant')
        
        return int.from_bytes((points * 255).astype(np.uint8).tobytes(), 'big')
    
    def _pack_radar_data(self, radar_data):
        """Pack radar data into raw format"""
        if isinstance(radar_data, dict) and 'points' in radar_data:
            data = radar_data['points'].flatten()[:16]  # 128/8 = 16 bytes
        else:
            # Multiple radars - use front radar
            data = radar_data.get('RADAR_FRONT', {}).get('points', np.zeros(16)).flatten()[:16]
        
        if len(data) < 16:
            data = np.pad(data, (0, 16 - len(data)), 'constant')
        
        return int.from_bytes((data * 255).astype(np.uint8).tobytes(), 'big')
    
    def _pack_imu_data(self, imu_data):
        """Pack IMU data into raw format"""
        # Combine position and orientation
        pos = imu_data['position'][:3]
        ori = imu_data['orientation'][:3] if len(imu_data['orientation']) == 3 else imu_data['orientation'][:3]
        
        data = np.array(pos + ori + [imu_data['accuracy'], 0])  # 8 values, 64/8 = 8 bytes
        
        return int.from_bytes((data * 255).astype(np.uint8).tobytes(), 'big')
    
    def stop_stream(self):
        """Stop dataset streaming"""
        self.stop_streaming = True
        if self.streaming_thread:
            self.streaming_thread.join()
        print("🛑 Dataset streaming stopped")

if __name__ == "__main__":
    # Demo usage
    streamer = DatasetStreamer()
    
    print("🚀 Dataset Loader Demo")
    print("=" * 50)
    
    # Load dataset info
    streamer.kitti_loader.load_sequence_info()
    streamer.nuscenes_loader.load_scene_info()
    
    print("\n✅ Dataset loaders ready for real-time streaming!")
    print("Use start_kitti_stream() or start_nuscenes_stream() to begin")
