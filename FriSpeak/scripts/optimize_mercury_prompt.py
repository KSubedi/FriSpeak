#!/usr/bin/env python3
"""Compatibility wrapper for the renamed intelligence prompt harness."""

from pathlib import Path
import runpy
import sys

target = Path(__file__).with_name("optimize_intelligence_prompt.py")
sys.argv[0] = str(target)
runpy.run_path(str(target), run_name="__main__")
