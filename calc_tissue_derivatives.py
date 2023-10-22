#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Aug  7 09:55:49 2023

@author: cvriend + chatGPT
"""


import argparse
import pandas as pd
import os


def main():
    parser = argparse.ArgumentParser(description='Calculate derivatives and powers of columns in a text file')
    parser.add_argument('input_file', help='Path to the input text file')
    parser.add_argument('output_file', help='Path to the output text file')
    parser.add_argument('label', help='Label for custom column names')
    args = parser.parse_args()
    #temp=os.path.split(args.input_file)[0]


    # Read the input text file into a Pandas DataFrame
    df = pd.read_csv(args.input_file, delimiter='\t',header=None,names=[args.label])  # Use the appropriate delimiter

    # Calculate derivatives for Column B and create custom column name
    derivative_column_name = args.label + '_derivative1'
    df[derivative_column_name] = df[args.label].diff()

    # Calculate powers for Column A and create custom column name
    power_column_name = args.label + '_power2'
    df[power_column_name] = df[args.label] ** 2

    # Calculate powers for the derivatives and create custom column name
    power_derivative_column_name = args.label + '_derivative1_power2'
    df[power_derivative_column_name] = df[derivative_column_name] ** 2
    df=df.round(4)

    # Save the result to the output text file
    df.to_csv(args.output_file, sep='\t', index=False,na_rep='n/a')  # Use the same delimiter as the input file

    print("Calculations completed. Results saved to", args.output_file)

if __name__ == '__main__':
    main()
