#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Dec 28 11:02:32 2022

@author: cvriend
"""

import pandas as pd
import os 
import argparse



parser = argparse.ArgumentParser('add headers to timeseries file')

# required arguments
parser.add_argument('--timeseriesfile', action="store", dest="timeserie", required=True,
                    help='full path to timeseries file')
parser.add_argument('--atlasids', action="store", dest="atlasid", required=True,
                    help='full path to file with atlas IDs')

# parse arguments
args = parser.parse_args()
timeserie=args.timeserie
atlasid=args.atlasid


df_time=pd.read_csv(timeserie,header=None,delim_whitespace=True)
df_atlas=pd.read_csv(atlasid,delim_whitespace=True,index_col=[0],header=None,usecols=[0,1])
# drop Unknown value
df_atlas.drop(df_atlas.loc[df_atlas[1]=='Unknown'].index, inplace=True)
# atlas names > column names
df_time.columns=df_atlas[1].tolist()

# save to csv file
df_time.to_csv(os.path.splitext(timeserie)[0] + '.csv',index=False)

