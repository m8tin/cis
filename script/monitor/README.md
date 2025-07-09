
Monitoring - How it works
=========================

Basics
------

You have to set up the monitoring host first. That host will monitor your other machines.
Execute `/cis/script/monitor/setupMonitoringHost.sh` to start the process.

As usual you can configure this feature via definitions.
```
# Path of this feature's scripts       : '/cis/script                 /monitor'
# Path of the corresponding definitions: '/cis/definitions/YOUR.DOMAIN/monitor'
ls -lha '/cis/script/monitor'
ls -lha '/cis/definitions/YOUR.DOMAIN/monitor'
```

You can modify the appearance and place your own `check.css` or `logo.png` into the definitions folder:
 - /cis/definitions/YOUR.DOMAIN/monitor/check.css
This feature will use these files with a higher priority.

After the change, you must call `/cis/script/monitor/setupMonitoringHost.sh` again,  
because it creates links in '/var/www/html/' and gives the definitions priority over the script.



Dashboard
---------

You can set up an dashboard following this manual [SETUP_DASHBOARD.md](SETUP_DASHBOARD.md)
