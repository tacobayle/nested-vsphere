#!/bin/bash
/home/ubuntu/.local/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 -m 007 wsgi:app