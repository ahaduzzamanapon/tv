import sys
import os
# Absolute paths — __file__ issue avoid করতে
APP_DIR      = "/home/lcsyxfen/tv.ehealthfinder.com"
VENV_PACKAGES = "/home/lcsyxfen/virtualenv/tv.ehealthfinder.com/3.10/lib/python3.10/site-packages"
if VENV_PACKAGES not in sys.path:
    sys.path.insert(0, VENV_PACKAGES)
if APP_DIR not in sys.path:
    sys.path.insert(0, APP_DIR)
os.chdir(APP_DIR)
from api import app as application