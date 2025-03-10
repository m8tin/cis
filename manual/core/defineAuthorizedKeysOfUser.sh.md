[core/defineAuthorizedKeysOfUser.sh](../core/defineAuthorizedKeysOfUser.sh)
===========================================================================

This script defines the `authorized_keys` file of the given user.
It will create a link pointing to the file in definitions to distribute the same settings across all hosts.

__Parameters:__
  1. USER (mandantory) Name of the user who will receive the ssh settings.
