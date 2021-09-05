from __future__ import annotations

import datetime
import functools
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path

import click
import matplotlib.pyplot as pp
import pandas as pd
import seaborn as sns


@click.group()
def cli():
    pass


@dataclass
class Stats:
    name: str
    run: str
    pattern: str  # mixed, random, linear
    operation: str  # read, write
    speed: float  # in mb/s

    @staticmethod
    def from_run(new, resultfile: Path) -> list[Stats]:

        results = json.loads(resultfile.read_text())
        jobs = results["jobs"]

        def get(name, value):
            job = next(j for j in jobs if j["jobname"] == name)
            # NOTE there are also bw_dev and other stats that could be interesting
            return job[value]["bw_mean"] / 1e3  # in mb/s

        return [
            new("mixed", "read", get("mixed", "read")),
            new("mixed", "write", get("mixed", "write")),
            new("random", "read", get("random-read", "read")),
            new("random", "write", get("random-write", "write")),
            new("linear", "read", get("linear-read", "read")),
            new("linear", "write", get("linear-write", "write")),
        ]

    @staticmethod
    def from_runs(folder: Path) -> list[Stats]:
        return [
            stat
            for name in folder.iterdir()
            if name.is_dir()
            for run in name.glob("*.json")
            for stat in Stats.from_run(
                functools.partial(Stats, name.name, run.stem),
                run,
            )
        ]


@cli.command()
@click.option("--basefolder", default="./runs")
def summary(basefolder):

    basefolder = Path(basefolder).expanduser()

    stats = Stats.from_runs(basefolder)
    df = pd.DataFrame(stats)

    sns.set_theme("paper", palette="colorblind")
    sns.catplot(
        data=df,
        kind="bar",
        col="pattern",
        hue="operation",
        x="name",
        y="speed",
        legend=True,
        legend_out=True,
    )
    pp.savefig(str(basefolder / "plots.png"), bbox_inches="tight")


@cli.command()
@click.option("--basefolder", default="./runs")
@click.option("--name", default="debug")
@click.option("--testfile", default="./disk-test-file")
@click.option("--repeat", default=1)
def run(basefolder, name, testfile, repeat):

    basefolder = Path(basefolder).expanduser()
    basefolder.mkdir(parents=True, exist_ok=True)
    (basefolder / name).mkdir(parents=True, exist_ok=True)

    for i in range(repeat):

        now = datetime.datetime.now().isoformat(timespec="seconds")
        resultsfile = basefolder / name / f"{now}.json"
        assert resultsfile.parent.exists()
        assert not resultsfile.exists()

        testfile = Path(testfile).expanduser()
        assert not testfile.exists()

        description = describe_location(testfile.parent)

        print(f"run test for {testfile}")
        print(f"with results in {resultsfile}")
        print(description)

        run_fio(testfile, resultsfile, description)


def describe_location(path) -> str:

    mount = (
        subprocess.run(
            ["findmnt", "--noheadings", "--output", "SOURCE", "--target", str(path)],
            capture_output=True,
            text=True,
            check=True,
        )
        .stdout.split("\n")[0]
        .strip()
    )

    devices = subprocess.run(
        ["lsblk", "--inverse", "--output", "+model", mount],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()

    return devices


def run_fio(testfile, resultsfile, description):

    try:
        command = [
            "fio",
            "--filename",
            str(testfile),
            "--output-format=json",
            "--output",
            str(resultsfile),
            "--description",
            json.dumps(description).strip('"'),
            # settings inspired by https://arstech.net/how-to-measure-disk-performance-iops-with-fio-in-linux/
            "fio-job",
        ]
        subprocess.run(command, check=True)
        print()

    finally:
        testfile.unlink(missing_ok=True)


if __name__ == "__main__":
    cli()
