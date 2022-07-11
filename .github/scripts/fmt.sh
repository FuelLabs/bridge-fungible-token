#!/usr/bin/env bash

PROJECT=$1


if [ ${{ matrix.project }} = 'POC/script' ]; then
    cd ${{ matrix.project }}
    cargo fmt --verbose --check
fi
