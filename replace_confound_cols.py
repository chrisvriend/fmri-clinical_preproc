#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 12 10:39:41 2023

@author: cvriend + chatGPT
"""

import argparse
import pandas as pd
import os

def replace_columns(file1, file2, output_file):
    # Load the data from the CSV files
    file1_df = pd.read_csv(file1,delimiter='\t')
    file2_df = pd.read_csv(file2,delimiter='\t')

    # Iterate through the headers in file2_df and replace corresponding columns in file1_df
    for header in file2_df.columns:
        if header in file1_df.columns:
            file1_df[header] = file2_df[header]

    # Save the modified file1_df to the specified output CSV file
    file1_df.to_csv(output_file, sep='\t', index=False,na_rep='n/a')  # Use the same delimiter as the input file

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Replace columns in one CSV file with columns from another CSV file.')
    parser.add_argument('file1', help='Input CSV file to modify')
    parser.add_argument('file2', help='CSV file containing replacement columns')
    parser.add_argument('output_file', help='Output CSV file to save the modified data')

    args = parser.parse_args()

    replace_columns(args.file1, args.file2, args.output_file)
