"""A checkout's simulator is retired once a newer iOS runtime is installed, and only then."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from sim_retire_stale import stale_devices  # noqa: E402

NAME = "iPhone 17 [a1b2c3d4]"
IOS_26_5 = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
IOS_27_0 = "com.apple.CoreSimulator.SimRuntime.iOS-27-0"


def _runtime(identifier: str, version: str, available: bool = True) -> dict:
    return {"identifier": identifier, "version": version, "name": f"iOS {version}", "isAvailable": available}


def _device(name: str = NAME, udid: str = "U1", available: bool = True) -> dict:
    return {"name": name, "udid": udid, "state": "Shutdown", "isAvailable": available}


class StaleDeviceTests(unittest.TestCase):
    def test_device_on_older_runtime_is_stale(self) -> None:
        runtimes = [_runtime(IOS_26_5, "26.5"), _runtime(IOS_27_0, "27.0")]
        found = stale_devices(NAME, {IOS_26_5: [_device()]}, runtimes)
        self.assertEqual([d["udid"] for d, _ in found], ["U1"])
        self.assertIn("iOS 26.5", found[0][1])

    def test_newer_runtime_without_this_device_type_is_not_the_target(self) -> None:
        iphone_17 = "com.apple.CoreSimulator.SimDeviceType.iPhone-17"
        ios_27_1 = {
            **_runtime("com.apple.CoreSimulator.SimRuntime.iOS-27-1", "27.1"),
            "supportedDeviceTypes": [{"identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"}],
        }
        runtimes = [_runtime(IOS_27_0, "27.0"), ios_27_1]
        device = {**_device(), "deviceTypeIdentifier": iphone_17}
        self.assertEqual(stale_devices(NAME, {IOS_27_0: [device]}, runtimes), [])

    def test_device_on_newest_runtime_is_kept(self) -> None:
        runtimes = [_runtime(IOS_26_5, "26.5"), _runtime(IOS_27_0, "27.0")]
        self.assertEqual(stale_devices(NAME, {IOS_27_0: [_device()]}, runtimes), [])

    def test_versions_compare_numerically(self) -> None:
        ios_26_10 = "com.apple.CoreSimulator.SimRuntime.iOS-26-10"
        runtimes = [_runtime(IOS_26_5, "26.5"), _runtime(ios_26_10, "26.10")]
        self.assertEqual(stale_devices(NAME, {ios_26_10: [_device()]}, runtimes), [])

    def test_device_whose_runtime_was_uninstalled_is_stale(self) -> None:
        runtimes = [_runtime(IOS_27_0, "27.0")]
        found = stale_devices(NAME, {IOS_26_5: [_device(available=False)]}, runtimes)
        self.assertEqual([d["udid"] for d, _ in found], ["U1"])

    def test_device_whose_runtime_is_briefly_unavailable_is_kept(self) -> None:
        runtimes = [_runtime(IOS_26_5, "26.5", available=False), _runtime(IOS_27_0, "27.0")]
        self.assertEqual(stale_devices(NAME, {IOS_26_5: [_device(available=False)]}, runtimes), [])

    def test_runtimes_above_the_selected_sdk_are_not_the_target(self) -> None:
        # A beta Xcode's runtime is installed alongside the selected stable one.
        runtimes = [_runtime(IOS_26_5, "26.5"), _runtime(IOS_27_0, "27.0")]
        self.assertEqual(stale_devices(NAME, {IOS_26_5: [_device()]}, runtimes, sdk_version="26.5"), [])
        found = stale_devices(NAME, {IOS_27_0: [_device()]}, runtimes, sdk_version="26.5")
        self.assertEqual([d["udid"] for d, _ in found], ["U1"])

    def test_sdk_cap_ignores_patch_versions(self) -> None:
        ios_26_5_1 = "com.apple.CoreSimulator.SimRuntime.iOS-26-5-1"
        runtimes = [_runtime(IOS_26_5, "26.5"), _runtime(ios_26_5_1, "26.5.1")]
        found = stale_devices(NAME, {IOS_26_5: [_device()]}, runtimes, sdk_version="26.5")
        self.assertIn("target is iOS 26.5.1", found[0][1])

    def test_other_names_are_never_touched(self) -> None:
        runtimes = [_runtime(IOS_26_5, "26.5"), _runtime(IOS_27_0, "27.0")]
        devices = {
            IOS_26_5: [
                _device(name="iPhone 17 [ffffffff]", udid="other-clone"),
                _device(name=f"Clone 1 of {NAME}", udid="xcodebuild-clone"),
                _device(name="iPhone 17", udid="xcode-default"),
            ]
        }
        self.assertEqual(stale_devices(NAME, devices, runtimes), [])

    def test_nothing_is_retired_without_an_ios_runtime(self) -> None:
        runtimes = [_runtime(IOS_26_5, "26.5", available=False)]
        self.assertEqual(stale_devices(NAME, {IOS_26_5: [_device()]}, runtimes), [])


if __name__ == "__main__":
    unittest.main()
