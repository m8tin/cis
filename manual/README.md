Manual
======

Each script `${FULL_SCRIPTNAME}.sh` has it's corresponding manual here:
 - `manuals/${FULL_SCRIPTNAME}.sh.md`

According to the rule above, this directory `manuals/core/*`  
has the same structure as `../core/*` and contains all manuals explaining the core functionality.

And this directory `manuals/script/*`  
has the same structure as `../script/*` and contains all manuals explaining the purpose of each script.



Core functionality
------------------

This set of scripts is the absolute minimum to provide the core functionality:
 - `setupCoreOntoThisHost.sh` bootstraps an empty new host, after the scripts repository was cloned  
   [Read this for further details](./setupCoreOntoThisHost.sh.md)
 - `setupCoreOntoThisHost.sh` needs [`../core/addAndCheckGitRepository.sh`](./core/addAndCheckGitRepository.sh.md)
 - `setupCoreOntoThisHost.sh` needs [`../core/addNormalUser.sh`](./core/addNormalUser.sh.md)
 - `setupCoreOntoThisHost.sh` needs [`../core/addToCrontabEveryHour.sh`](./core/addToCrontabEveryHour.sh.md)
 - `setupCoreOntoThisHost.sh` needs [`../core/defineAuthorizedKeysOfUser.sh`](./core/defineAuthorizedKeysOfUser.sh.md)
 - `setupCoreOntoThisHost.sh` needs [`../core/ensureUsageOfDefinitions.sh`](./core/ensureUsageOfDefinitions.sh.md)



The scripts
-----------
