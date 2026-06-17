#!/usr/bin/env python

from inspect import cleandoc


class ldifCreator:
    def __init__(self):
        self.uid = 30000
        self.gid = 230000

    def write_base_structure(self):
        """Write the base LDAP structure (domain, OUs)."""
        print(
            cleandoc(
                """
                dn: dc=ldap,dc=test
                objectClass: top
                objectClass: domain
                dc: ldap
                description: dc=ldap,dc=test
                aci: (targetattr="dc || description || objectClass")(targetfilte
                 r="(objectClass=domain)")(version 3.0; acl "Enable anyone domai
                 n read"; allow (read, search, compare)(userdn="ldap:///anyone")
                 ;)
                aci: (targetattr=*)(version 3.0; acl "Enable anyone read"; allow
                 (read, search, compare)(userdn="ldap:///anyone");)

                dn: ou=users,dc=ldap,dc=test
                objectClass: top
                objectClass: organizationalUnit
                ou: users

                dn: ou=groups,dc=ldap,dc=test
                objectClass: top
                objectClass: organizationalUnit
                ou: groups
                """
            )
        )
        print("")

    def write_user(self, username):
        print(
            cleandoc(
                f"""
                dn: cn={username},ou=users,dc=ldap,dc=test
                objectClass: posixAccount
                objectClass: inetuser
                objectClass: top
                cn: {username}
                uid: {username}
                uidNumber: {self.uid}
                gidNumber: {self.uid}
                homeDirectory: /home/{username}
                userPassword:: e1NIQTI1Nn1MdEJuWm5sZFdLVHlMVkVhWnk4Z3ByQ1cwLzViV
                 nE4NmRFWjRxYU5XL1lJPQ==
                """
            )
        )
        print("")
        self.uid += 1

    def write_group(self, groupname, users, groups):
        print(
            cleandoc(
                f"""
                dn: cn={groupname},ou=groups,dc=ldap,dc=test
                objectClass: posixGroup
                objectClass: groupOfNames
                objectClass: top
                cn: {groupname}
                gidNumber: {self.gid}
                """
            )
        )
        if users:
            for member in users:
                print(f"member: cn={member},ou=users,dc=ldap,dc=test")
                print(f"memberUID: {member}")
        if groups:
            for member in groups:
                print(f"member: cn={member},ou=groups,dc=ldap,dc=test")
        print("")
        self.gid += 1

    def write_user_10k_30k(self):
        self.write_user("user_10k")
        self.write_user("user_30k")

    def write_group_1k_XY(self):
        for group in range(1, 51):
            members = []
            group_name = "group_1k_%.2d" % group
            for user in range(1, 1001):
                user_name = "member_1k_%.2d_%.4d" % (group, user)
                members.append(user_name)
                self.write_user(user_name)
            if group >= 1 and group <= 10:
                members.append("user_10k")
            if group >= 1 and group <= 30:
                members.append("user_30k")
            self.write_group(group_name, members, None)

    def write_group_plain_jumbo(self):
        members = []
        for user in range(1, 50001):
            user_name = "member_plain_jumbo_%.5d" % (user)
            members.append(user_name)
            self.write_user(user_name)
        self.write_group("group_plain_jumbo", members, None)

    def _group_1k_list(self, start, end):
        members = []
        for a in range(start, end + 1):
            members.append("group_1k_%.2d" % (a))
        return members

    def write_nested_groups(self):
        self.write_group(
            "nested_group_1_1", None, self._group_1k_list(1, 10) + ["nested_group_1_2"]
        )
        self.write_group(
            "nested_group_1_2", None, self._group_1k_list(11, 20) + ["nested_group_1_3"]
        )
        self.write_group("nested_group_1_3", None, self._group_1k_list(21, 30))
        self.write_group(
            "nested_group_2_1", None, self._group_1k_list(31, 40) + ["nested_group_2_2"]
        )
        self.write_group("nested_group_2_2", None, self._group_1k_list(41, 50))

    def run(self):
        self.write_base_structure()
        self.write_group_plain_jumbo()
        self.write_user_10k_30k()
        self.write_group_1k_XY()
        self.write_nested_groups()


if __name__ == "__main__":
    ldifCreator().run()
