#
# Copyright (c) 2013-2019 Balabit
# All Rights Reserved.
#

import sys
import json
import requests
import os.path

from requests_toolbelt.adapters.source import SourceAddressAdapter
from os import path

# Authentication-Authorization plugins for SCB are installed to /opt/scb/var/plugins/aa/.
# It is a lot easier just to SSH into SCB to test your plugin rather than uploading through
# the UI to test changes.  Just upload it the first time, the work on it from there.

# The lock files for SCB are stored in /opt/scb/var/lock/.  You will want to delete the
# xml and config lock files in that directory.

# The logging goes to /var/log/messages-<DAY>, where <DAY> is the three character represent-
# ation of the day of the week, e.g. /var/log/messages-Fri.

_certificate_path = '/etc/spp/server.crt'
if path.exists('/etc/spp/client.pem'):
    _client_identity_path = '/etc/spp/client.pem'
else:
    _client_identity_path = ("/etc/spp/client.crt", "/etc/spp/client.key")
_join_config = '/etc/spp/join.json'
_urlPattern = 'https://{0}:8649/service/SPSInteractive/v3/Plugin'
_auth_segment = '/Authentication'
_authz_segment = '/Authorization'
_headers = {'Authorization': 'PsmPlugin certuser'}


class Plugin(object):
    def __init__(self, configuration=None):
        self.configuration = configuration

    def authenticate(self, session_id, session_cookie, cookie, protocol, connection_name,
                     client_ip, client_port, key_value_pairs):

        print("Session authenticate; BEGINNING MARKER")
        print("Session authenticate; " + str(locals()))

        if self.configuration:
            print("Plugin configuration; " + self.configuration)

        # This plugin calls SpsInteractive REST interface to validate the token that is encoded in
        # the user name.  Note that it also returns a gateway user and gateway groups.  Gateway
        # groups will be used for selecting channel policies.

        session_cookie.setdefault("SessionId", session_id)
        metadata = ','.join(['{0}={1}'.format(key, key_value_pairs[key]) for key in sorted(key_value_pairs.keys())])
        token = key_value_pairs.pop('token', None)
        if not token:
            return {'verdict': 'NEEDINFO',
                    'question': ('token', 'Enter the one-time-use token: ') 
                    }

        username = key_value_pairs.pop('username', None)
        if not username:
            return {'verdict': 'NEEDINFO',
                    'question': ('username', 'Enter the user name: ') 
                    }

        vaultaddress = key_value_pairs.pop('vaultaddress', None)
        if not vaultaddress:
            if self.configuration:
                try:
                    j = ''
                    for line in self.configuration.splitlines():
                        if not line.startswith('#'):
                            j += line
                    c = json.loads(j)
                    vaultaddress = c['vaultaddress']
                except Exception, e:
                    print(str(e))
                    pass

            if not vaultaddress:
                vaultaddress = self._get_vaultaddress()
                return {'verdict': 'NEEDINFO',
                        'question': ('vaultaddress', 'Enter SPP IP address[Suggested-{0}]: '.format(vaultaddress)) 
                       }

        try:
            auth_url = _urlPattern.format(vaultaddress) + _auth_segment
            queryParams = {'token': token, 'sessionId': session_cookie["SessionId"]}
            print("Session authenticate; {0}?{1}".format(auth_url, queryParams))
            session = self._prepare_request()
            r = session.get(auth_url, params=queryParams, headers=_headers,
                             verify=_certificate_path, cert=_client_identity_path)
            if r.status_code == 200:
                data = r.json()
                cookie['session_key'] = data['SessionKey']
                session_cookie["SessionKey"] = data["SessionKey"]
                session_cookie["VaultAddress"] = vaultaddress
                session_cookie["UserName"] = username
                return {'verdict': 'ACCEPT',
                        'gateway_user': data['User'],
                        'gateway_groups': data['Groups'],
                        'additional_metadata': metadata,
                        'cookie': cookie,
                        'session_cookie': session_cookie
                       }
            else:
                print("[ERROR] Session Authenticate; Request failed with status='{0}'".format(str(r.status_code)))
                print("response: " + str(vars(r)))
                return {'verdict': 'DENY',
                        'Result': 'Denied by server',
                        'additional_metadata': metadata
                       }
        except Exception, e:
            print(
                "[ERROR] Session Authenticate; Failed to notify the session internal service exception='{0}'".format(str(e)))
            return {'verdict': 'DENY',
                    'Result': 'Failed to contact the authentication service',
                    'additional_metadata': metadata
                   }

    def _prepare_request(self):
        with open(_join_config, "r") as config_file:
            config = json.load(config_file)

        session = requests.Session()
        session.mount("https://", SourceAddressAdapter(config["sps_cluster_interface_ip"]))

        return session

    def _get_vaultaddress(self):
        with open(_join_config, "r") as config_file:
            config = json.load(config_file)

        return config["spp_primary_ip"]

    def authorize(self, session_id, session_cookie, cookie, protocol, connection_name, client_ip, client_port,
                  gateway_user, gateway_groups, target_server, target_port, target_username, key_value_pairs):

        print("Session authorize; BEGINNING MARKER")
        print("Session authorize; " + str(locals()))

        # This plugin calls SessionsInternal REST interface to validate that the user is authorized to access
        # target server.

        metadata = ','.join(['{0}={1}'.format(key, key_value_pairs[key]) for key in sorted(key_value_pairs.keys())])
        token = key_value_pairs.pop('token', None)

        if token:
            vaultaddress = session_cookie['VaultAddress']
            authz_url = _urlPattern.format(vaultaddress) + _authz_segment

            username = session_cookie['UserName']

            try:
                queryParams = {'token': token, 'sessionId': session_cookie["SessionId"], 'sessionKey': session_cookie['SessionKey'],
                               'clientIp': client_ip, 'clientPort': client_port,
                               'targetServer': target_server, 'targetPort': target_port,
                               'targetUserName': username, 'protocol': protocol}
                print("Session authorize; {0}?{1}".format(authz_url, queryParams))
                session = self._prepare_request()
                r = session.get(authz_url, headers=_headers, params=queryParams,
                                 verify=_certificate_path, cert=_client_identity_path)
                if r.status_code == 200:
                    data = r.json()
                    cookie['session_key'] = data['SessionKey']
                    return {'verdict': 'ACCEPT',
                            'session_cookie': session_cookie,
                            'cookie': cookie,
                            'additional_metadata': metadata}
                else:
                    print("[ERROR] Session Authorize; Request failed with status='{0}'".format(str(r.status_code)))
                    print("response: " + str(vars(r)))
                    return {'verdict': 'DENY',
                            'Result': 'Denied by server',
                            'additional_metadata': metadata
                            }
            except Exception, e:
                print(
                    "[ERROR] Session Authorize; Failed to notify the session internal service exception='{0}'".format(str(e)))
                return {'verdict': 'DENY',
                        'Result': 'Failed to contact the authorization service',
                        'additional_metadata': metadata
                        }

    def session_ended(self, session_id, session_cookie, cookie):
        print("Session ended; BEGINNING MARKER")
        print("Session ended; " + str(locals()))

        try:
            vaultaddress = session_cookie['VaultAddress']
            url = _urlPattern.format(vaultaddress) + _auth_segment

            queryParams = {'token': cookie.get('session_key', None),
                           'sessionId': session_id,
                           'sessionKey': session_cookie['SessionKey']}
            print("Session ended; {0}?{1}".format(url, queryParams))
            session = self._prepare_request()
            r = session.delete(url, params=queryParams, headers=_headers,
                                verify=_certificate_path, cert=_client_identity_path)
            if r.status_code == 200:
                return {'cookie': cookie,
                        'session_cookie': session_cookie}
            else:
                print("[ERROR] Session Ended; Failed to notify the session internal service status_code='{0}'".format(
                    r.status_code))
                return None
        except Exception, e:
            print("[ERROR] Session Ended; Failed to notify the session internal service exception='{0}'".format(str(e)))
            return None
