import sys
import os

# Virtualenv site-packages সরাসরি path এ add করো (os.execl ছাড়াই)
venv_packages = "/home/lcsyxfen/virtualenv/tv.ehealthfinder.com/3.10/lib/python3.10/site-packages"
if venv_packages not in sys.path:
    sys.path.insert(0, venv_packages)

APP_DIR = os.path.dirname(os.path.abspath(__file__))
if APP_DIR not in sys.path:
    sys.path.insert(0, APP_DIR)

from api import app as application
