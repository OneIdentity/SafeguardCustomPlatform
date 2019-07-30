{
    "name": "TSO/E",
    "description": "TSO/E (TN3270)",
    "states":
    {
        "_START_": {
            "next_states": ["USERNAME_ANCHOR"],
            "type": "tn3270"
        },
        "USERNAME_ANCHOR": {
            "patterns": ["`Enter \"LOGON\" followed by the TSO userid.`"],
            "side": "server",
            "next_states": ["USERNAME"]
        },
        "USERNAME": {
            "patterns": ["[`L``l`][`O``o`][`G``g`][`O``o`][`N``n`]` `(?P<username>[^#00-#40]*)"],
            "event": "username",
            "side": "client",
            "next_states": ["PASSWORD_ANCHOR"]
        },
        "PASSWORD_ANCHOR": {
            "patterns": ["#1d#60#40`Password  ===>`#11(?P<sbapassword>..)#1d(?P<modifyattr>.)"],
            "side": "server",
            "next_states": ["PASSWORD"]
        },
        "PASSWORD": {
            "patterns": ["#11{sbapassword}(?P<password>[^#00-#3f]*)"],
            "event": "password",
            "side": "client",
            "next_states": ["SUCCESS", "FAILURE"]
        },
        "SUCCESS": {
            "patterns": ["`IKJ56455I`"],
            "side": "server",
            "event": "success"
        },
        "FAILURE": {
            "patterns": ["`PASSWORD NOT AUTHORIZED`"],
            "side": "server",
            "event": "failure",
            "next_states": ["PASSWORD"]
        }
    }
}
