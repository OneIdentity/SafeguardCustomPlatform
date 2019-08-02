{
    "name": "IBM-Systemi-as400-tn3270",
    "description": "AS400 (TN3270) Pattern File For IBMi Series",
    "states":
    {
        "_START_": {
            "next_states": ["SIGN_ON_PAGE"],
            "type": "tn3270"
        },
        "SIGN_ON_PAGE": {
            "patterns": ["#40`Sign On`"],
            "side": "server",
            "next_states": ["USERNAME_ANCHOR"]
        },
        "USERNAME_ANCHOR": {
            "patterns": ["`User`[` `,`.`]*"],
            "side": "server",
            "next_states": ["PASSWORD_ANCHOR"]
        },
        "PASSWORD_ANCHOR": {
            "patterns": ["`Password`[` `,`.`,#00]*#29..(?P<modifyattr>.)"],
            "side": "server",
            "next_states": ["USERNAME"]
        },
        "USERNAME": {
            "patterns": ["#11..(?P<username>[^#00-#40]*)"],
            "event": "username",
            "side": "client",
            "next_states": ["PASSWORD"]
        },
        "PASSWORD": {
            "patterns": ["#11.*#11..(?P<password>[^#00-#3f]*)"],
            "event": "password",
            "side": "client",
            "next_states": ["SUCCESS", "FAILURE"]
        },
        "SUCCESS": {
            "patterns": ["`IBM i Main Menu`"],
            "side": "server",
            "event": "success"
        },
        "FAILURE": {
            "patterns": ["#40`Sign On`"],
            "side": "server",
            "event": "failure",
            "next_states": ["USERNAME"]
        }
    }
}
