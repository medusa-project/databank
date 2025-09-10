#!/usr/bin/env python
#
# GNU General Public License https://www.gnu.org/licenses/gpl-3.0.txt
#
"""
Illinois Data Bank API client version 2
Usage:
   python databank_api_client_v2.py <DATASET> <TOKEN> <FILE> [<SYSTEM>]
Upload FILE to an existing draft DATASET created in Illinois Data Bank (https://databank.illinois.edu),
authenticating with TOKEN on SYSTEM, which is the production system by default.
Arguments:
 FILE      input file
 DATASET   dataset key, obtained on screen opened by API button on dataset edit screen
 TOKEN     API token, obtained on screen opened by API button on dataset edit screen
 SYSTEM    optional system indicator (local | development | production ), default is production
"""
from __future__ import division
from __future__ import print_function
from tusclient import client

import sys
import os
import requests

if len(sys.argv) < 4:
   sys.exit("Usage: python databank_api_client_v2.py <DATASET> <TOKEN> <FILE> [<SYSTEM>]")

five_mb = 5 * 1024 * 1024
success_code = 200

dataset_key = sys.argv[1]
token = sys.argv[2]
filepath = sys.argv[3]

if len(sys.argv) > 4:
   system = sys.argv[4]
else:
   system = "production"

create_endpoint = "http"
upload_endpoint = "http"
filename = 'unknown'
size = 0
mime_type = 'unknown/unknown'

# If a SYSTEM argument is provided, validate it, otherwise use production as default.
valid_system_list = ["local", "development", "production"]
if not any(system in s for s in valid_system_list):

   print(sys.argv)
   print("SYSTEM argument must be one of local|development|production, production is default.\n")
   sys.exit("Usage: python databank_api_client_v2.py <DATASET> <TOKEN> <FILE> [<SYSTEM>]")

# ensure file exists
if os.path.isfile(filepath):
   file_info = os.stat(filepath)
   size = file_info.st_size

   filepath_split = filepath.split('/')
   filename = filepath_split[-1]
   print("uploading " + filename + " ...")
else:
   print("FILE argument must be the path to the file on the local filesystem to be uploaded.\n")
   sys.exit("Usage: python databank_api_client_v2.py <DATASET> <TOKEN> <FILE> [<SYSTEM>]")

# generate endpoints

if system == 'production':
   create_endpoint += "s://databank.illinois.edu/api/dataset/" + dataset_key + "/datafile"
   upload_endpoint += "s://databank.illinois.edu/files/"

elif system == 'development':
   create_endpoint += "s://demo.databank.illinois.edu/api/dataset/" + dataset_key + "/datafile"
   upload_endpoint += "s://demo.databank.illinois.edu/files/"

elif system == 'local':
   create_endpoint += "://localhost:3000/api/dataset/" + dataset_key + "/datafile"
   upload_endpoint += "://localhost:3000/files/"

else:
   sys.exit('Internal Error, please contact the Research Data Service databank@library.illinois.edu')


def upload_datafile():
   # setup tus client
   tus_client = client.TusClient(upload_endpoint, headers={'Authorization': 'Token token=' + token})

   # for multipart uploads, s3 requires that all chunks except last be at least 5 MB
   five_mb = 5 * 1024 * 1024  # 5MB

   # set up tus client uploader
   uploader = tus_client.uploader(filepath, chunk_size=five_mb)

   # upload the entire file, chunk by chunk
   uploader.upload()

   # get the tus_url from the tus client uploader
   tus_url = uploader.url

   create_response = requests.post(create_endpoint,
                                   headers={'Authorization': 'Token token=' + token},
                                   data={'filename': filename, 'tus_url': tus_url, 'size': size,
                                         'dataset_key': dataset_key}, verify=True)
   print(create_response.text)


try:
   upload_datafile()

except Exception as ex:
   print("An unexpected error occurred, please contact the Research Data Service databank@library.illinois.edu.\n")
   print("Exception: %s" % ex)
