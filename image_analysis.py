#!/usr/bin/env python3

import re
import subprocess
import argparse
from termcolor import colored

LAYER_SIZE_THR_YELLOW = 50 * 10**6  # 50 MB
LAYER_SIZE_THR_RED = 200 * 10**6    # 200 MB

def run(x):
    return subprocess.check_output(x).decode('utf-8')

def sizeof_fmt(num, suffix='B'):
    for unit in ['','K','M','G','T','P','E','Z']:
        if abs(num) < 1024.0:
            return "%3.1f %s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)

def main():
    # define arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('--logfile', required=True, help="Docker build log file to process")
    parser.add_argument('--image', required=True, help='Docker image name associated with the log')
    parsed = parser.parse_args()

    # get arguments
    logfile = parsed.logfile
    image = parsed.image

    # put lines from the logfile in a list
    lines = []
    with open(logfile) as fin:
        lines = [l for l in fin]

    # define RegEx patterns
    step_pattern = re.compile("Step ([0-9]+)/([0-9]+) : (.*)")
    open_layer = re.compile(" ---> ([0-9a-z]{12})")

    # find "Step XY/TOT" lines
    steps_idx = [i for i in range(len(lines)) if step_pattern.match(lines[i])] + [len(lines)]

    # get layers size from docker
    image_history = run(['docker', 'history', '-H=false', '--format', '{{.ID}}:{{.Size}}', image])
    image_history = [l.split(':') for l in image_history.split('\n') if len(l.strip()) > 0]

    # create map {layerid: size_bytes}
    layer_to_size_bytes = dict()
    for l in image_history:
        layerid, layersize = l
        if layerid == 'missing':
            continue
        layer_to_size_bytes[layerid] = int(layersize)

    # for each Step, find the layer ID
    first_layer = None
    last_layer = None
    for i,j in zip(steps_idx, steps_idx[1:]):
        cur_step_lines = lines[i:j]
        open_layers = [open_layer.match(l) for l in cur_step_lines if open_layer.match(l)]
        # get Step info
        print('-' * 22)
        stepline = lines[i]
        stepno = step_pattern.match(stepline).group(1)
        steptot = step_pattern.match(stepline).group(2)
        stepcmd = re.sub(' +', ' ', step_pattern.match(stepline).group(3))
        # get info about layer ID and size
        layerid = None
        layersize = 'ND'
        if len(open_layers) > 0:
            layerid = open_layers[0].group(1)
            if first_layer is None:
                first_layer = layerid
            last_layer = layerid
        if layerid in layer_to_size_bytes:
            layersize = sizeof_fmt(layer_to_size_bytes[layerid])
            color = 'yellow' if layer_to_size_bytes[layerid] > LAYER_SIZE_THR_YELLOW else 'green'
            color = 'red' if layer_to_size_bytes[layerid] > LAYER_SIZE_THR_RED else color
            layersize = colored(layersize, color, attrs=['reverse'])
        # print info about the current layer
        print(
            'Layer ID: %s\n  Step: %s/%s\n  Command: \n\t%s\n  Size: %s' % (
            layerid,
            stepno,
            steptot,
            stepcmd,
            layersize
        ))
        print()

    # compute size of the base image
    first_layer_idx = [i for i in range(len(image_history)) if image_history[i][0] == first_layer][0]
    base_image_size = sum([int(l[1]) for l in image_history[first_layer_idx:]])

    # compute size of the final image
    final_image_size = sum([int(l[1]) for l in image_history])

    # print info about the whole image
    print()
    print('=' * 22)
    print('Final image name: %s' % image)
    print('Final image size: %s' % sizeof_fmt(final_image_size))
    print('Base image size: %s' % sizeof_fmt(base_image_size))
    print('Your image added %s to the base image.' % sizeof_fmt(final_image_size-base_image_size))
    print('=' * 22)
    print()
    print('Always ask yourself, can I do better than that? ;)')
    print('Done!')
    print()


if __name__ == '__main__':
    main()
