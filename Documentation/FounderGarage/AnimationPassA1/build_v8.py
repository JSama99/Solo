"""Rebuild Founder Garage V8 from the preserved V7 package and USD overlay."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
ASSETS = REPO / "App/RealityKit/FounderGarage"
BASE = ASSETS / "founder_garage_v7.usdz"
OUTPUT = ASSETS / "founder_garage_v8.usdz"
OVERLAY = HERE / "founder_garage_v8_overlay.usda"


def run(*arguments: str, cwd: Path) -> None:
    subprocess.run(arguments, cwd=cwd, check=True)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="solo-garage-v8-") as temporary:
        staging = Path(temporary)
        with zipfile.ZipFile(BASE) as archive:
            archive.extractall(staging)
        (staging / "founder_garage_v7.usdc").rename(
            staging / "founder_garage_v7_base.usdc"
        )
        shutil.copy2(OVERLAY, staging / OVERLAY.name)
        run(
            "usdcat",
            OVERLAY.name,
            "--flatten",
            "--skipSourceFileComment",
            "-o",
            "founder_garage_v8.usdc",
            cwd=staging,
        )
        run("usdzip", "-a", "founder_garage_v8.usdc", str(OUTPUT), cwd=staging)


if __name__ == "__main__":
    main()
