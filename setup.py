#!/usr/bin/env python3
from setuptools import setup

setup(
    name="wlo-topic-assistant",
    version="0.1.0",
    description="A utility to map arbitrary text to the WLO/OEH topics vocabulary based on keyword matching.",
    author="",
    author_email="",
    packages=["wlo_topic_assistant"],
    install_requires=[
        d for d in open("requirements.txt").readlines() if not d.startswith("--")
    ],
    package_dir={"": "."},
    entry_points={"console_scripts": ["wlo-topic-assistant = wlo_topic_assistant.webservice:main"]},
)
