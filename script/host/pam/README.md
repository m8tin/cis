How to use
==========

You can use this script `ssh-notify-root-login.sh` in two different ways.

1.) Use it as is
----------------

In this use case you just have to call this script once.

It will register itself to the file `/etc/pam.d/sshd` and because there is just a logfile defined you will get that functionality.

Each ssh login of user root will be logged into this file:  
 - `/var/log/ssh-notify-root-login.sh.log`

2.) Use your own configuration
------------------------------

In this case copy the script to a custom location or put it into your definitions, e.g.:
 - `/cis/definitions/your.domain.net/script/host/pam/ssh-notify-root-login.sh`
  
There you can modify the following variables:
 - _LOGFILE 
 - _EMAIL_ADDRESS
 - _SLACK_WEBHOOK_URL

Setting these variables to "" will disable the feature.

If you set a varaible to a valid value, e.g. a webhook-url of slack, you will get a slack-message on each login.
 