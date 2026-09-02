#!/bin/bash
set -ex

# Install required Data Analytics & ML runtime libraries
sudo python3 -m pip install --no-cache-dir \
    findspark \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    pyarrow
