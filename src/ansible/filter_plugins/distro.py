class FilterModule(object):
    def filters(self):
        return {
            'distro_includes': self.distro_includes
        }

    def distro_includes(self, distro, version, extra=""):
        """ Create list of distribution specific include files. """
        min_version = 1
        if distro.lower() == 'fedora':
            min_version = 34
        elif distro.lower() == 'centos':
            # RHEL 8.x and Centos Strem 8 are the same, keep this around for now!
            min_version = 8

        out = [f'{distro}{extra}.yml']
        out.extend([ f'{distro}{x}{extra}.yml' for x in range(min_version, int(version) + 1) ])
        out.reverse()

        return out
