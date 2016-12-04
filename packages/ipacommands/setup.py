"""IPA commands
"""
import atexit
import glob
import os
import shlex
import shutil
import subprocess
import sys

from distutils import unixccompiler
from distutils.command.build_scripts import build_scripts \
    as distutils_build_scripts
from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext as setuptools_build_ext
from setuptools.command.install_lib import install_lib \
    as setuptools_install_lib


HERE = os.path.dirname(os.path.abspath(__file__))


# distutils does not have an API to override compiler class
# Let's monkey patch!
OrigUnixCCompiler = unixccompiler.UnixCCompiler

class CustomUnixCCompiler(OrigUnixCCompiler):
    # Redirect link_shared_object to link_exectuable
    def link_shared_object(self, objects, output_filename, output_dir=None,
                           libraries=None, library_dirs=None,
                           runtime_library_dirs=None, export_symbols=None,
                           debug=0, extra_preargs=None, extra_postargs=None,
                           build_temp=None, target_lang=None):
        # unused: export_symbols, build_temp
        # remove pythonX.Y lib
        libraries = list(
            lib for lib in libraries
            if not lib.startswith('python')
        )
        output_progname = output_filename
        return self.link_executable(
            objects,
            output_progname=output_progname,
            output_dir=output_dir,
            libraries=libraries, library_dirs=library_dirs,
            runtime_library_dirs=runtime_library_dirs,
            debug=debug, extra_preargs=extra_preargs,
            extra_postargs=extra_postargs,
            target_lang=target_lang)

    def _fix_lib_args(self, libraries, library_dirs, runtime_library_dirs):
        return libraries, library_dirs, runtime_library_dirs


unixccompiler.UnixCCompiler = CustomUnixCCompiler


class build_ext(setuptools_build_ext):
    def get_ext_filename(self, ext_name):
        # Don't add '.so' extension
        return ext_name


class build_scripts(distutils_build_scripts):
    """Custom build_scripts

    Copy executables form build_lib to script dir.
    """
    def run(self):
        # run and get build_ext
        self.run_command('build_ext')
        build_ext = self.get_finalized_command('build_ext')
        for i, name in enumerate(self.scripts):
            libfile = os.path.join(build_ext.build_lib, name)
            # add binary as script
            self.scripts[i] = libfile
        distutils_build_scripts.run(self)

    def copy_scripts(self):
        # simple version of copy_script that does not try to read the
        # executable as Python scripts.
        self.mkpath(self.build_dir)
        outfiles = []
        for script in self.scripts:
            outfile = os.path.join(self.build_dir, os.path.basename(script))
            self.copy_file(script, outfile)
            os.chmod(outfile, 0o755)
            outfiles.append(outfile)
        return outfiles, outfiles


class install_lib(setuptools_install_lib):
    """Custom install_lib

    Don't install the executables as libraries.
    """
    def install(self):
        return []


def prepare():
    # copy files and symlink dirs
    # files need to be copied to create a working sdist bundle.
    link_names = [
        'asn1', 'client', 'util', 'Contributors.txt',
        'COPYING', 'COPYING.openssl', 'ipasetup.py'
    ]
    removes = []
    for name in link_names:
        src = os.path.join(HERE, os.pardir, name)
        dest = os.path.join(HERE, name)
        if not os.path.exists(dest):
            if os.path.isdir(src):
                os.symlink(src, dest)
            else:
                shutil.copy(src, dest)
            removes.append(dest)

    # create empty config.h
    config_h = os.path.join(HERE, 'client', 'config.h')
    if not os.path.isfile(config_h):
        with open(config_h, 'w') as f:
            f.write('/* empty */\n')
        removes.append(config_h)

    return removes


def cleanup(removes):
    for name in removes:
        if os.path.exists(name):
            os.unlink(name)


def pkgconfig(flags, *pkgs):
    cmd = ['pkg-config', flags]
    cmd.extend(pkgs)
    out = subprocess.check_output(cmd)
    if isinstance(out, bytes):
        out = out.decode(sys.getfilesystemencoding())
    return shlex.split(out)


def get_extensions(version, ipajoin=False):
    cfiles = [
        'asn1/ipa_asn1.c',
        'client/config.c',
        'client/ipa-client-common.c',
        'util/ipa_krb5.c'
    ] + glob.glob('asn1/asn1c/*.c')

    headers = [
        'asn1/ipa_asn1.h',
        'client/config.h',
        'client/ipa-client-common.h',
        'util/ipa_krb5.h'
    ] + glob.glob('asn1/asn1c/*.h')

    include_dirs = ['asn1', 'asn1/asn1c', 'client', 'util', '.']

    pkgs = ('nss', 'krb5', 'libcrypto', 'popt', 'libsasl2', 'ini_config')
    extra_compile_args = []
    extra_compile_args.extend(pkgconfig('--cflags', *pkgs))

    extra_link_args = ['-lldap_r', '-llber']  # OpenLDAP has no .pc
    extra_link_args.extend(pkgconfig('--libs', *pkgs))

    macros = [
        ('IPACONFFILE', '"/etc/ipa/default.conf"'),
        ('LOCALEDIR', '"/usr/local/share/locale"'),
        ('VERSION', '"{}"'.format(version)),
    ]

    extensions = [
        Extension(
            'ipa-getkeytab',
            sources=['client/ipa-getkeytab.c'] + cfiles,
            depends=headers,
            extra_compile_args=extra_compile_args,
            extra_link_args=extra_link_args,
            include_dirs=include_dirs,
            define_macros=macros,
        ),
        Extension(
            'ipa-rmkeytab',
            sources=['client/ipa-rmkeytab.c'] + cfiles,
            depends=headers,
            extra_compile_args=extra_compile_args,
            extra_link_args=extra_link_args,
            include_dirs=include_dirs,
            define_macros=macros,
        ),
    ]

    if ipajoin:
        xmlrpc_compile_args = pkgconfig('--cflags', 'xmlrpc_client')
        xmlrpc_link_args = pkgconfig('--libs', 'xmlrpc_client')
        extensions.append(
            Extension(
                'ipa-join',
                sources=['client/ipa-join.c'] + cfiles,
                depends=headers,
                extra_compile_args=extra_compile_args + xmlrpc_compile_args,
                extra_link_args=extra_link_args + xmlrpc_link_args,
                include_dirs=include_dirs,
                define_macros=macros,
            )
        )
    return extensions


if __name__ == '__main__':
    # removes = prepare()
    # atexit.register(cleanup, removes)

    from ipasetup import ipasetup  # noqa: E402

    exts = get_extensions(version="4.5", ipajoin=False)

    ipasetup(
        name='ipacommands',
        doc=__doc__,
        ext_modules=exts,
        cmdclass={
            'build_ext': build_ext,
            'build_scripts': build_scripts,
            'install_lib': install_lib,
        },
        scripts=[ext.name for ext in exts],
    )
