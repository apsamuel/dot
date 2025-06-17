#!/usr/bin/env bash

blendFile="${1:-${HOME}/Pictures/Blends/logoB.blend}"

blendFileName="$(basename ${blendFile%.blend})"
outputFolder="${2:-${HOME}/Pictures/Blends/renders/${blendFileName}}"
if [[ -d  "$outputFolder" ]]; then
    echo "directory exists"
else
    echo "creating output folder: ${outputFolder}"
    mkdir -v "$outputFolder"
fi

/Applications/Blender.app/Contents/MacOS/Blender --background ${blendFile} --render-anim --render-output "${outputFolder}/${blendFileName}-######.png" --format PNG --engine BLENDER_EEVEE --log "*"
