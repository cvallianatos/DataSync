# Verbs or routes are defined from the consumer's point of view

import os
import glob
import platform
from flask import Flask, request, abort, jsonify, send_from_directory
import socket
import urllib.parse

api = Flask(__name__)

@api.route("/platform", methods=["GET"])
def myPlatform():
    return platform.system()

# List files

@api.route("/list/", methods=["GET"])
def list_files():
    # Endpoint to list files on the server.
    pathname = request.args['pathname']
    files = []
    unEncodeTrgDir = urllib.parse.unquote(pathname)
    print(unEncodeTrgDir)
    myTarget = "/Users/chris/Library/Mobile Documents/com~apple~CloudDocs/Documents" + unEncodeTrgDir 
    for filename in glob.iglob(myTarget + '**/*.*', recursive=True):
       if not os.path.isdir(filename):
            print(filename)
            files.append(filename)
    return jsonify(files)

# Send files

@api.route("/send/", methods=["POST"])
def send():
    pathname = request.args['pathname']
    unEncodeTrgDir = urllib.parse.unquote(pathname)
    
    myFile = os.path.basename(unEncodeTrgDir)
    myPath = os.path.dirname(unEncodeTrgDir)

    if not os.path.exists(myPath):
        os.makedirs(myPath)
    
    uploaded_file = request.files['file']
    filename = uploaded_file.filename

    if myFile != '':
        try:
            uploaded_file.save(os.path.join(myPath, filename))
        except Exception:
            abort(404)
    return "", 201

# Receive files

@api.route("/receive/", methods=["GET"])
def receive():

    pathname = request.args['pathname']
    unEncodeTrgDir = urllib.parse.unquote(pathname)
    # Download a file.
    myFile = os.path.basename(unEncodeTrgDir)
    myPath = os.path.dirname(unEncodeTrgDir)

    try:
        return send_from_directory(myPath, myFile, as_attachment=True)
    except FileNotFoundError:
        abort(404)

if __name__ == "__main__":
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    myIP = s.getsockname()[0]
    s.close()
    print ("Using IP: ",myIP, "\n")

    api.run(host=myIP, port=8000)
    