#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2020 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2020 The MITRE Corporation                                      #
#                                                                           #
# Licensed under the Apache License, Version 2.0 (the "License");           #
# you may not use this file except in compliance with the License.          #
# You may obtain a copy of the License at                                   #
#                                                                           #
#    http://www.apache.org/licenses/LICENSE-2.0                             #
#                                                                           #
# Unless required by applicable law or agreed to in writing, software       #
# distributed under the License is distributed on an "AS IS" BASIS,         #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

from datetime import datetime
import os
import json
import subprocess
import unittest
from typing import Tuple, Dict, Any, List, ClassVar


def get_test_media(file_name: str) -> str:
    return os.path.join(os.path.dirname(__file__), 'data', file_name)


class BaseTestCliRunner(unittest.TestCase):
    _container_id: ClassVar[str]
    _docker_exec_args: ClassVar[Tuple[str, ...]]
    _test_start_time = datetime.now().astimezone()

    # Provided by subclass
    image_name: ClassVar[str]
    detection_type: ClassVar[str]

    @classmethod
    def setUpClass(cls):
        full_image_name = cls._get_full_image_name()
        proc = subprocess.run(
            ('docker', 'run', '--rm', '-d', full_image_name, '-d'),
            stdout=subprocess.PIPE, text=True, check=True)
        cls._container_id = proc.stdout.strip()
        cls._docker_exec_args = ('docker', 'exec', '-i', cls._container_id, 'runner')

    @classmethod
    def tearDownClass(cls):
        subprocess.run(('docker', 'stop', cls._container_id), check=True)

    @classmethod
    def _get_full_image_name(cls):
        test_registry = os.getenv('TEST_REGISTRY', '')
        if len(test_registry) > 0 and test_registry[-1] != '/':
            test_registry += '/'

        test_img_tag = os.getenv('TEST_IMG_TAG')
        if not test_img_tag:
            test_img_tag = 'latest'
        if test_img_tag[0] == ':':
            test_img_tag = test_img_tag[1:]

        return f'{test_registry}{cls.image_name}:{test_img_tag}'


    @classmethod
    def run_cli_runner_stdin_media(cls, media_path: str, *runner_args: str) -> Dict[str, Any]:
        full_command = cls._docker_exec_args + runner_args
        with open(media_path) as media_file, \
                subprocess.Popen(full_command, stdin=media_file, stdout=subprocess.PIPE,
                                 text=True) as proc:
            return json.load(proc.stdout)


    @classmethod
    def run_cli_runner(cls, media_path, *runner_args: str) -> Dict[str, Any]:
        file_name = os.path.basename(media_path)
        container_path = os.path.join('/root', file_name)
        subprocess.run(('docker', 'cp', media_path, f'{cls._container_id}:{container_path}'),
                       check=True)

        full_command = cls._docker_exec_args + (container_path,) + runner_args
        with subprocess.Popen(full_command, stdout=subprocess.PIPE, text=True) as proc:
            return json.load(proc.stdout)


    def get_image_tracks(
            self,
            expected_path,
            expected_mime_type: str,
            expected_job_props: Dict[str, str],
            expected_media_metadata: Dict[str, str],
            output_object: Dict[str, Any]) -> List[Dict[str, Any]]:

        self._assertOuterJsonCorrect(
            expected_mime_type, expected_job_props, expected_media_metadata, output_object)
        self.assertEqual(expected_path, output_object['media'][0]['path'])

        tracks = self._get_tracks(output_object)
        for track in tracks:
            self._assertTrackIsFromImage(track)
        return tracks


    def get_video_tracks(
            self,
            expected_mime_type: str,
            expected_job_props: Dict[str, str],
            expected_media_metadata: Dict[str, str],
            output_object: Dict[str, Any]) -> List[Dict[str, Any]]:

        self._assertOuterJsonCorrect(
            expected_mime_type, expected_job_props, expected_media_metadata, output_object)

        return self._get_tracks(output_object)


    @classmethod
    def _get_tracks(cls, output_object: Dict[str, Any]) -> List[Dict[str, Any]]:
        return output_object['media'][0]['output'][cls.detection_type][0]['tracks']



    def _assertOuterJsonCorrect(
            self,
            expected_mime_type: str,
            expected_job_props: Dict[str, str],
            expected_media_metadata: Dict[str, str],
            output_object: Dict[str, Any]) -> None:
        start_time = datetime.fromisoformat(output_object['timeStart'])
        end_time = datetime.fromisoformat(output_object['timeStop'])
        self.assertGreater(end_time, start_time)
        self.assertGreater(start_time, self._test_start_time)
        self.assertEqual(expected_job_props, output_object['jobProperties'])

        self.assertEqual(1, len(output_object['media']))
        media_entry = output_object['media'][0]
        self.assertEqual(expected_mime_type, media_entry['mimeType'])
        self.assertEqual(expected_media_metadata, media_entry['mediaMetadata'])

        self.assertEqual(1, len(media_entry['output']))
        self.assertIn(self.detection_type, media_entry['output'])

        detection_type_entry = media_entry['output'][self.detection_type]
        self.assertEqual(1, len(detection_type_entry))
        self.assertEqual(1, len(detection_type_entry[0]))
        self.assertIn('tracks', detection_type_entry[0])


    def _assertTrackIsFromImage(self, track):
        self.assertEqual(0, track['startOffsetFrame'])
        self.assertEqual(0, track['stopOffsetFrame'])
        self.assertEqual(0, track['startOffsetTime'])
        self.assertEqual(0, track['stopOffsetTime'])
        self.assertEqual(self.detection_type, track['type'])

        detections = track['detections']
        self.assertEqual(1, len(detections))
        detection = detections[0]
        self.assertEqual(track['exemplar'], detection)
        self.assertEqual(track['trackProperties'], detection['detectionProperties'])
        self.assertEqual(0, detection['offsetFrame'])
        self.assertEqual(0, detection['offsetTime'])



# noinspection DuplicatedCode
class TestCppCliRunnerWithOcvFace(BaseTestCliRunner):
    image_name = 'openmpf_ocv_face_detection'
    detection_type = 'FACE'
    _face_image = get_test_media('meds-af-S419-01_40deg.jpg')
    _default_job_properties = {'MAX_FEATURE': '250',
                               'MAX_OPTICAL_FLOW_ERROR': '4.7',
                               'MIN_FACE_SIZE': '48',
                               'MIN_INITIAL_CONFIDENCE': '10',
                               'MIN_INIT_POINT_COUNT': '45',
                               'MIN_POINT_PERCENT': '0.70',
                               'VERBOSE': '0'}

    def test_can_run_image_jobs(self):
        output_object = self.run_cli_runner_stdin_media(self._face_image, '-t', 'image', '-')
        tracks = self.get_image_tracks(
            '/dev/stdin', 'image/octet-stream', self._default_job_properties, {}, output_object)

        self.assertEqual(1, len(tracks))
        track = tracks[0]
        self.assertAlmostEqual(55, track['confidence'])
        self.assertEqual(0, len(track['trackProperties']))

        detection = track['detections'][0]
        self.assertEqual(95, detection['x'])
        self.assertEqual(169, detection['y'])
        self.assertEqual(292, detection['width'])
        self.assertEqual(292, detection['height'])
        self.assertAlmostEqual(55, detection['confidence'])
        self.assertEqual(0, len(detection['detectionProperties']))


    def test_can_run_job_with_job_properties_and_media_metadata(self):
        output_object = self.run_cli_runner_stdin_media(
            self._face_image,
            '-t', 'image', '-', '-P', 'ROTATION=40', '-P', 'TEST=5',
            '-M', 'META_KEY1=META_VAL1', '-M', 'META_KEY2=META_VAL2')

        expected_job_props = {**self._default_job_properties, 'ROTATION': '40', 'TEST': '5'}
        expected_media_metadata = {'META_KEY1': 'META_VAL1', 'META_KEY2': 'META_VAL2'}
        tracks = self.get_image_tracks(
            '/dev/stdin', 'image/octet-stream', expected_job_props, expected_media_metadata,
            output_object)

        self.assertEqual(1, len(tracks))
        track = tracks[0]
        self.assertAlmostEqual(58, track['confidence'])
        self.assertEqual(1, len(track['trackProperties']))
        self.assertAlmostEqual(40, float(track['trackProperties']['ROTATION']))

        detection = track['detections'][0]
        self.assertEqual(680, detection['x'])
        self.assertEqual(375, detection['y'])
        self.assertEqual(316, detection['width'])
        self.assertEqual(316, detection['height'])
        self.assertAlmostEqual(58, detection['confidence'])
        self.assertEqual(1, len(detection['detectionProperties']))
        self.assertAlmostEqual(40, float(detection['detectionProperties']['ROTATION']))


    def test_can_handle_empty_results(self):
        output_object = self.run_cli_runner_stdin_media(
            self._face_image, '-t', 'image', '-', '-P', 'AUTO_ROTATE=true', '-M', 'ROTATION=180')

        expected_job_props = {**self._default_job_properties, 'AUTO_ROTATE': 'true'}
        tracks = self.get_image_tracks(
            '/dev/stdin', 'image/octet-stream', expected_job_props, {'ROTATION': '180'},
            output_object)
        self.assertEqual(0, len(tracks))


    def test_can_run_video_jobs(self):
        video_name = 'ff-region-motion-face-first10-frames.avi'
        output_object = self.run_cli_runner(get_test_media(video_name))
        tracks = self.get_video_tracks(
            'video/x-msvideo', self._default_job_properties,
            {'FPS': '30.0', 'MIME_TYPE': 'video/x-msvideo'}, output_object)
        self.assertEqual(f'/root/{video_name}', output_object['media'][0]['path'])

        self.assertEqual(2, len(tracks))

        track1 = tracks[0]
        self.assertEqual(0, track1['startOffsetFrame'])
        self.assertEqual(9, track1['stopOffsetFrame'])
        self.assertEqual(0, track1['startOffsetTime'])
        self.assertEqual(300, track1['stopOffsetTime'])
        self.assertAlmostEqual(24, track1['confidence'])
        self.assertEqual(10, len(track1['detections']))

        exemplar1 = track1['exemplar']
        self.assertEqual(0, exemplar1['offsetFrame'])
        self.assertEqual(0, exemplar1['offsetTime'])
        self.assertEqual(74, exemplar1['x'])
        self.assertEqual(101, exemplar1['y'])
        self.assertEqual(197, exemplar1['width'])
        self.assertEqual(197, exemplar1['height'])
        self.assertAlmostEqual(24, exemplar1['confidence'])


        track2 = tracks[1]
        self.assertEqual(0, track2['startOffsetFrame'])
        self.assertEqual(9, track2['stopOffsetFrame'])
        self.assertEqual(0, track2['startOffsetTime'])
        self.assertEqual(300, track2['stopOffsetTime'])
        self.assertAlmostEqual(33, track2['confidence'])
        self.assertEqual(10, len(track2['detections']))

        exemplar2 = track2['exemplar']
        self.assertEqual(0, exemplar2['offsetFrame'])
        self.assertEqual(0, exemplar2['offsetTime'])
        self.assertEqual(416, exemplar2['x'])
        self.assertEqual(88, exemplar2['y'])
        self.assertEqual(201, exemplar2['width'])
        self.assertEqual(202, exemplar2['height'])
        self.assertAlmostEqual(33, exemplar2['confidence'])


    def test_video_with_begin_end_set(self):
        video_name = 'ff-region-motion-face-first10-frames.avi'
        output_object = self.run_cli_runner(
            get_test_media(video_name), '--begin', '2', '--end', '4')
        tracks = self.get_video_tracks(
            'video/x-msvideo', self._default_job_properties,
            {'FPS': '30.0', 'MIME_TYPE': 'video/x-msvideo'}, output_object)
        self.assertEqual(f'/root/{video_name}', output_object['media'][0]['path'])

        self.assertEqual(2, len(tracks))

        track1 = tracks[0]
        self.assertEqual(2, track1['startOffsetFrame'])
        self.assertEqual(4, track1['stopOffsetFrame'])
        self.assertEqual(67, track1['startOffsetTime'])
        self.assertEqual(133, track1['stopOffsetTime'])
        self.assertAlmostEqual(21, track1['confidence'])
        self.assertEqual(3, len(track1['detections']))

        exemplar1 = track1['exemplar']
        self.assertEqual(2, exemplar1['offsetFrame'])
        self.assertEqual(67, exemplar1['offsetTime'])
        self.assertEqual(74, exemplar1['x'])
        self.assertEqual(100, exemplar1['y'])
        self.assertEqual(200, exemplar1['width'])
        self.assertEqual(200, exemplar1['height'])
        self.assertAlmostEqual(21, exemplar1['confidence'])


        track2 = tracks[1]
        self.assertEqual(2, track2['startOffsetFrame'])
        self.assertEqual(4, track2['stopOffsetFrame'])
        self.assertEqual(67, track2['startOffsetTime'])
        self.assertEqual(133, track2['stopOffsetTime'])
        self.assertAlmostEqual(30, track2['confidence'])
        self.assertEqual(3, len(track2['detections']))

        exemplar2 = track2['exemplar']
        self.assertEqual(2, exemplar2['offsetFrame'])
        self.assertEqual(67, exemplar2['offsetTime'])
        self.assertEqual(419, exemplar2['x'])
        self.assertEqual(91, exemplar2['y'])
        self.assertEqual(198, exemplar2['width'])
        self.assertEqual(198, exemplar2['height'])
        self.assertAlmostEqual(30, exemplar2['confidence'])



class TestCppCliRunnerWithTesseract(BaseTestCliRunner):
    image_name = 'openmpf_tesseract_ocr_text_detection'
    detection_type = 'TEXT'
    _default_job_properties = {'ADAPTIVE_HIST_CLIP_LIMIT': '2.0',
                               'ADAPTIVE_HIST_TILE_SIZE': '5',
                               'ADAPTIVE_THRS_BLOCKSIZE': '51',
                               'ADAPTIVE_THRS_CONSTANT': '5',
                               'COMBINE_OSD_SCRIPTS': 'true',
                               'ENABLE_OSD_AUTOMATION': 'true',
                               'ENABLE_OSD_FALLBACK': 'true',
                               'FULL_REGEX_SEARCH': 'true',
                               'INVALID_MIN_IMAGE_SIZE': '3',
                               'INVERT': 'false',
                               'MAX_OSD_SCRIPTS': '1',
                               'MAX_PARALLEL_PAGE_THREADS': '4',
                               'MAX_PARALLEL_SCRIPT_THREADS': '4',
                               'MAX_PIXELS': '10000000',
                               'MAX_TEXT_TRACKS': '0',
                               'MIN_HEIGHT': '60',
                               'MIN_OSD_PRIMARY_SCRIPT_CONFIDENCE': '0.5',
                               'MIN_OSD_SCRIPT_SCORE': '50.0',
                               'MIN_OSD_SECONDARY_SCRIPT_THRESHOLD': '0.80',
                               'MIN_OSD_TEXT_ORIENTATION_CONFIDENCE': '2.0',
                               'ROTATE_AND_DETECT': 'true',
                               'ROTATE_AND_DETECT_MIN_OCR_CONFIDENCE': '95.0',
                               'STRUCTURED_TEXT_ENABLE_ADAPTIVE_HIST_EQUALIZATION': 'false',
                               'STRUCTURED_TEXT_ENABLE_ADAPTIVE_THRS': 'false',
                               'STRUCTURED_TEXT_ENABLE_HIST_EQUALIZATION': 'false',
                               'STRUCTURED_TEXT_ENABLE_OTSU_THRS': 'false',
                               'STRUCTURED_TEXT_SCALE': '1.6',
                               'STRUCTURED_TEXT_SHARPEN': '-1.0',
                               'TAGGING_FILE': 'text-tags.json',
                               'TESSERACT_LANGUAGE': 'script/Latin',
                               'TESSERACT_OEM': '3',
                               'TESSERACT_PSM': '3',
                               'UNSTRUCTURED_TEXT_ENABLE_ADAPTIVE_HIST_EQUALIZATION': 'false',
                               'UNSTRUCTURED_TEXT_ENABLE_ADAPTIVE_THRS': 'false',
                               'UNSTRUCTURED_TEXT_ENABLE_HIST_EQUALIZATION': 'false',
                               'UNSTRUCTURED_TEXT_ENABLE_OTSU_THRS': 'false',
                               'UNSTRUCTURED_TEXT_ENABLE_PREPROCESSING': 'false',
                               'UNSTRUCTURED_TEXT_SCALE': '2.6',
                               'UNSTRUCTURED_TEXT_SHARPEN': '1.0'}

    def test_can_run_generic_job(self):
        pdf_name = 'test.pdf'
        output_object = self.run_cli_runner(get_test_media(pdf_name))
        tracks = self.get_image_tracks(
            f'/root/{pdf_name}', 'application/pdf', self._default_job_properties,
            {'MIME_TYPE': 'application/pdf'}, output_object)

        self.assertEqual(1, len(tracks))
        track = tracks[0]
        self.assertAlmostEqual(95, track['confidence'])
        expected_properties = {
            'MISSING_LANGUAGE_MODELS': '',
            'OSD_FALLBACK_OCCURRED': 'false',
            'OSD_PRIMARY_SCRIPT': 'NULL',
            'OSD_PRIMARY_SCRIPT_CONFIDENCE': '-1',
            'OSD_PRIMARY_SCRIPT_SCORE': '-1',
            'OSD_TEXT_ORIENTATION_CONFIDENCE': '-1',
            'PAGE_NUM': '1',
            'ROTATION': '0',
            'TAGS': '',
            'TEXT': 'Hello',
            'TEXT_LANGUAGE': 'script/Latin',
            'TRIGGER_WORDS': '',
            'TRIGGER_WORDS_OFFSET': ''
        }
        self.assertEqual(expected_properties, track['trackProperties'])

        self.assertEqual(1, len(track['detections']))
        detection = track['detections'][0]
        self.assertEqual(0, detection['x'])
        self.assertEqual(0, detection['y'])
        self.assertEqual(0, detection['width'])
        self.assertEqual(0, detection['height'])
        self.assertAlmostEqual(95, detection['confidence'])
        self.assertEqual(detection, track['exemplar'])
        self.assertEqual(expected_properties, detection['detectionProperties'])




# noinspection DuplicatedCode
class TestPythonCliRunner(BaseTestCliRunner):
    image_name = 'openmpf_east_text_detection'
    detection_type = 'TEXT REGION'
    _text_image = get_test_media('hello-world.png')
    _default_job_properties = {'BATCH_SIZE': '1',
                               'CONFIDENCE_THRESHOLD': '0.8',
                               'FINAL_PADDING': '0.0',
                               'MAX_SIDE_LENGTH': '-1',
                               'MERGE_MAX_ROTATION_DIFFERENCE': '10.0',
                               'MERGE_MAX_TEXT_HEIGHT_DIFFERENCE': '0.3',
                               'MERGE_MIN_OVERLAP': '0.01',
                               'MERGE_REGIONS': 'TRUE',
                               'MIN_STRUCTURED_TEXT_THRESHOLD': '0.01',
                               'NMS_MIN_OVERLAP': '0.1',
                               'ROTATE_AND_DETECT': 'FALSE',
                               'SUPPRESS_VERTICAL': 'TRUE',
                               'TEMPORARY_PADDING': '0.1'}


    def test_can_run_image_jobs(self):
        output_object = self.run_cli_runner_stdin_media(self._text_image, '-t', 'image', '-')
        tracks = self.get_image_tracks(
            '/dev/stdin', 'image/octet-stream', self._default_job_properties, {}, output_object)
        self.assertEqual(2, len(tracks))

        track1 = tracks[0]
        self.assertAlmostEqual(0.9999814, track1['confidence'])
        self.assertEqual(2, len(track1['trackProperties']))
        self.assertAlmostEqual(1.2726791, float(track1['trackProperties']['ROTATION']), places=2)
        self.assertEqual('STRUCTURED', track1['trackProperties']['TEXT_TYPE'])

        detection1 = track1['detections'][0]
        self.assertEqual(119, detection1['x'])
        self.assertEqual(126, detection1['y'])
        self.assertEqual(111, detection1['width'])
        self.assertEqual(33, detection1['height'])
        self.assertAlmostEqual(0.9999814, detection1['confidence'], places=2)


        track2 = tracks[1]
        self.assertAlmostEqual(0.9999863, track2['confidence'])
        self.assertEqual(2, len(track2['trackProperties']))
        self.assertAlmostEqual(1.181158, float(track2['trackProperties']['ROTATION']), places=2)
        self.assertEqual('STRUCTURED', track1['trackProperties']['TEXT_TYPE'])

        detection2 = track2['detections'][0]
        self.assertEqual(20, detection2['x'])
        self.assertEqual(125, detection2['y'])
        self.assertEqual(88, detection2['width'])
        self.assertEqual(35, detection2['height'])
        self.assertAlmostEqual(0.9999863, detection2['confidence'], places=2)


    def test_can_run_image_job_with_job_properties(self):
        output_object = self.run_cli_runner_stdin_media(
            self._text_image, '-t', 'image', '-', '-P', 'ROTATION=15')

        expected_job_props = {**self._default_job_properties, 'ROTATION': '15'}
        tracks = self.get_image_tracks(
            '/dev/stdin', 'image/octet-stream', expected_job_props, {}, output_object)

        self.assertEqual(1, len(tracks))
        track = tracks[0]
        self.assertAlmostEqual(0.99997675, track['confidence'], places=2)
        self.assertEqual(2, len(track['trackProperties']))
        self.assertAlmostEqual(4.490200000000016, float(track['trackProperties']['ROTATION']),
                               places=2)
        self.assertEqual('UNSTRUCTURED', track['trackProperties']['TEXT_TYPE'])

        detection = track['detections'][0]
        self.assertEqual(11, detection['x'])
        self.assertEqual(124, detection['y'])
        self.assertEqual(221, detection['width'])
        self.assertEqual(52, detection['height'])
        self.assertAlmostEqual(0.99997675, detection['confidence'], places=2)


    def test_can_run_video_job(self):
        video_file = get_test_media('hello.avi')
        output_object = self.run_cli_runner_stdin_media(video_file, '-', '-t', 'video')
        tracks = self.get_video_tracks(
            'video/octet-stream', self._default_job_properties, {'FPS': '1.0'}, output_object)
        self.assertTrue(output_object['media'][0]['path'].startswith('/tmp/'))

        self.assertEqual(3, len(tracks))

        track1 = tracks[0]
        self.assertEqual(0, track1['startOffsetFrame'])
        self.assertEqual(0, track1['stopOffsetFrame'])
        self.assertEqual(0, track1['startOffsetTime'])
        self.assertEqual(0, track1['stopOffsetTime'])
        self.assertAlmostEqual(0.99997926, track1['confidence'])
        self.assertEqual(2, len(track1['trackProperties']))
        self.assertAlmostEqual(1.243963, float(track1['trackProperties']['ROTATION']), places=2)
        self.assertEqual('UNSTRUCTURED', track1['trackProperties']['TEXT_TYPE'])

        self.assertEqual(1, len(track1['detections']))
        exemplar1 = track1['exemplar']
        self.assertEqual(exemplar1, track1['detections'][0])
        self.assertEqual(0, exemplar1['offsetFrame'])
        self.assertEqual(0, exemplar1['offsetTime'])
        self.assertEqual(89, exemplar1['x'])
        self.assertEqual(143, exemplar1['y'])
        self.assertEqual(88, exemplar1['width'])
        self.assertEqual(34, exemplar1['height'])
        self.assertAlmostEqual(0.99997926, exemplar1['confidence'], places=2)
        self.assertEqual(2, len(exemplar1['detectionProperties']))
        self.assertAlmostEqual(1.243963, float(exemplar1['detectionProperties']['ROTATION']),
                               places=2)
        self.assertEqual('UNSTRUCTURED', exemplar1['detectionProperties']['TEXT_TYPE'])


        track2 = tracks[1]
        self.assertEqual(1, track2['startOffsetFrame'])
        self.assertEqual(1, track2['stopOffsetFrame'])
        self.assertEqual(1000, track2['startOffsetTime'])
        self.assertEqual(1000, track2['stopOffsetTime'])
        self.assertAlmostEqual(0.9999789, track2['confidence'], places=2)
        self.assertEqual(2, len(track2['trackProperties']))
        self.assertAlmostEqual(1.2030252, float(track2['trackProperties']['ROTATION']), places=2)
        self.assertEqual('UNSTRUCTURED', track2['trackProperties']['TEXT_TYPE'])

        self.assertEqual(1, len(track2['detections']))
        exemplar2 = track2['exemplar']
        self.assertEqual(exemplar2, track2['detections'][0])
        self.assertEqual(1, exemplar2['offsetFrame'])
        self.assertEqual(1000, exemplar2['offsetTime'])
        self.assertEqual(88, exemplar2['x'])
        self.assertEqual(143, exemplar2['y'])
        self.assertEqual(88, exemplar2['width'])
        self.assertEqual(34, exemplar2['height'])
        self.assertAlmostEqual(0.9999789, exemplar2['confidence'], places=2)
        self.assertEqual(2, len(exemplar2['detectionProperties']))
        self.assertAlmostEqual(1.2030252, float(exemplar2['detectionProperties']['ROTATION']),
                               places=2)
        self.assertEqual('UNSTRUCTURED', exemplar2['detectionProperties']['TEXT_TYPE'])


        track3 = tracks[2]
        self.assertEqual(2, track3['startOffsetFrame'])
        self.assertEqual(2, track3['stopOffsetFrame'])
        self.assertEqual(2000, track3['startOffsetTime'])
        self.assertEqual(2000, track3['stopOffsetTime'])
        self.assertAlmostEqual(0.9999789, track3['confidence'], places=2)
        self.assertEqual(2, len(track3['trackProperties']))
        self.assertAlmostEqual(1.2030252, float(track3['trackProperties']['ROTATION']), places=2)
        self.assertEqual('UNSTRUCTURED', track3['trackProperties']['TEXT_TYPE'])

        self.assertEqual(1, len(track3['detections']))
        exemplar3 = track3['exemplar']
        self.assertEqual(exemplar3, track3['detections'][0])
        self.assertEqual(2, exemplar3['offsetFrame'])
        self.assertEqual(2000, exemplar3['offsetTime'])
        self.assertEqual(88, exemplar3['x'])
        self.assertEqual(143, exemplar3['y'])
        self.assertEqual(88, exemplar3['width'])
        self.assertEqual(34, exemplar3['height'])
        self.assertAlmostEqual(0.9999789, exemplar3['confidence'], places=2)
        self.assertEqual(2, len(exemplar3['detectionProperties']))
        self.assertAlmostEqual(1.2030252, float(exemplar3['detectionProperties']['ROTATION']),
                               places=2)
        self.assertEqual('UNSTRUCTURED', exemplar3['detectionProperties']['TEXT_TYPE'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
