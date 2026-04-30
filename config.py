# config.py — Database & App Configuration
# এই ফাইলে MySQL credentials রাখুন

DB_CONFIG = {
    "host":     "localhost",
    "user":     "lcsyxfen_tv",
    "password": "lcsyxfen_tv",          # আপনার MySQL password দিন
    "database": "lcsyxfen_tv",
    "charset":  "utf8mb4",
    "autocommit": True,
}

# cPanel shared hosting-এ সাধারণত:
# user     = cPanelUsername_dbuser
# database = cPanelUsername_tv
# উদাহরণ: user="ahad_root", database="ahad_tv"
