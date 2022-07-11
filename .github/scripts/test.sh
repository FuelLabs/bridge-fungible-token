#!/usr/bin/env bash

PROJECT=$1


if [ ${{ matrix.project }} = 'POC/script' ]; then
    cd ${{ matrix.project }}
    forc test
fi
