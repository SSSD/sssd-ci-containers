class FilterModule(object):
    def filters(self):
        return {
            'distro_includes': self.distro_includes
        }

    def distro_includes(self, distro, version):
        """ Create list of distribution specific include files. """
        min_version = 1
        if distro.lower() == 'fedora':
            min_version = 34
        elif distro.lower() == 'centos':
            min_version = 8

        out = [f'{distro}.yml']
        out.extend([ f'{distro}{x}.yml' for x in range(min_version, int(version) + 1) ])
        out.reverse()

        return out
