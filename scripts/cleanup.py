#!/usr/bin/env python3

from argparse import ArgumentParser, FileType

# Process an MDHC CSV input file.

def cleanup(args):
    ''' Main loop for cleanup'''

    for line in args.infile:

        # strip out BOM
        line = line.replace('\ufeff', '')

        # Add EOL if missing
        if line[-1:] != '\n':
            line += '\n'

        # Write the line back out
        args.outfile.write(line)


if __name__ == '__main__':
    # Setup command line arguments
    parser = ArgumentParser()

    parser.add_argument("-i", "--infile", required=True,
                        type=FileType('r', encoding='UTF-8'),
                        help="CSV input file")

    parser.add_argument("-o", "--outfile", required=True,
                        type=FileType('w', encoding='UTF-8'),
                        help="CSV output file")

    # Process command line arguments
    args = parser.parse_args()

    # Run the CSV validation and cleanup
    cleanup(args)
