#!/bin/bash
source /cis/core/base.module.sh



function ssh.onHostRun() {
    local _REMOTE_HOST _COMMAND
    base.set _REMOTE_HOST "${1:?"FQDN of server missing: e.g. host.example.net[:port]"}" '^([a-zA-Z0-9][a-zA-Z0-9@.-]*)+(:[0-9]+)?$'
    base.set _COMMAND "${2:?"COMMAND missing"}" "${REGEX[COMMAND]}"

    local _REMOTE_USER _REMOTE_HOSTNAME_FQDN _REMOTE_PORT _SOCKET
    _REMOTE_USER="@${_REMOTE_HOST}"                        #Ensures leading '@'
    _REMOTE_USER="${_REMOTE_USER%@*}"                      #Removes shortest matching pattern '@*' from the end   => @user or nothing
    _REMOTE_USER="${_REMOTE_USER##*@}"                     #Removes longest  matching pattern '*@' from the begin => user
    _REMOTE_USER="${_REMOTE_USER:-"$(whoami)"}"
    _REMOTE_HOSTNAME_FQDN="${_REMOTE_HOST}"
    _REMOTE_HOSTNAME_FQDN="${_REMOTE_HOSTNAME_FQDN##*@}"   #Removes longest  matching pattern '*@' from the begin
    _REMOTE_HOSTNAME_FQDN="${_REMOTE_HOSTNAME_FQDN%%:*}"   #Removes longest  matching pattern ':*' from the end
    _REMOTE_PORT="${_REMOTE_HOST}:"                        #Ensures tailing ':'
    _REMOTE_PORT="${_REMOTE_PORT#*:}"                      #Removes shortest matching pattern '*:' from the begin => 123: or nothing
    _REMOTE_PORT="${_REMOTE_PORT%%:*}"                     #Removes longest  matching pattern ':*' from the end   => 123
    _REMOTE_PORT="${_REMOTE_PORT:-"22"}"
    _SOCKET='~/.ssh/%r@%h:%p'
    readonly _REMOTE_USER _REMOTE_HOSTNAME_FQDN _REMOTE_PORT _SOCKET

    function checkOrStartSSHMaster() {
        timeout --preserve-status 1 ssh -O check -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} 2>&1 | grep -q -F 'Master running' \
            && return 0

        ssh -O stop -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} &> /dev/null
        ssh -o ControlMaster=auto \
            -o ControlPath=${_SOCKET} \
            -o ControlPersist=65 \
            -p ${_REMOTE_PORT} \
            -f ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} exit &> /dev/null \
            && return 0

        base.abort "FAILURE: Establishing SSH connection" "Is the setup ok?"
        return 1
    }

    checkOrStartSSHMaster \
        || return 1

    ssh -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} "${_COMMAND}"
}



# Check if this module was started correctly using source
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Script was executed directly
    echo "FAILURE: you are using this module 'ssh.module.sh' in a wrong way."
    echo "    It is intended as a utility library and should not be called directly."
    echo
    echo "Usage: Call this module at the beginning of your script e.g. like this:"
    echo
    echo '    #!/bin/bash'
    echo '    source /cis/core/base.module.sh'
    echo
    echo '    #Loads this module'
    echo '    base.loadModule ssh'
    echo
    echo "Now you can use the functions provided by this module inside your script:"
    echo "-------------------------------------------------------------------------"
    declare -F | grep "ssh." | cut -d" " -f3
    exit 1
fi
