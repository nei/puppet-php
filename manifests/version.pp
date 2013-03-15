# Installs a php version, and sets up phpenv
#
# Usage:
#
#     php::version { '5.3.20': }
#
# There are a number of predefined classes which can be used rather than
# using this class directly, which allows the class to be defined multiple
# times - eg. if you define it within multiple projects. For example:
#
#     include php::5-3-20
#
define php::version(
  $ensure    = 'installed',
  $version   = $name
) {
  require php
  include boxen::config

  # Install location
  $dest = "${php::config::root}/versions/${version}"

  # Log locations
  $error_log = "${php::config::logdir}/${version}.error.log"

  # Config locations
  $version_config_root  = "${php::config::configdir}/${version}"
  $php_ini              = "${version_config_root}/php.ini"
  $conf_d               = "${version_config_root}/conf.d"

  # Module location for PHP extensions
  $module_dir = "${dest}/modules"

  # Data directory for this version
  $version_data_root = "${php::config::datadir}/${version}"

  if $ensure == 'absent' {

    # If we're nuking a version of PHP also ensure we shut down
    # and get rid of the PHP FPM Service & config

    php::fpm { $version:
      ensure => 'absent'
    }

    file {
      [
        $dest,
        $version_config_root,
      ]:
      ensure => absent,
      force  => true
    }

  } else {

    # Data directory

    file { $version_data_root:
      ensure => directory,
    }

    # Set up config directories

    file { $version_config_root:
      ensure => directory,
    }

    file { $conf_d:
      ensure  => directory,
      purge   => true,
      force   => true,
      require => File[$version_config_root],
    }

    file { $module_dir:
      ensure  => directory,
      require => Php_version[$version],
    }

    # Install PHP!

    php_version { $version:
      user_home     => "/Users/${::boxen_user}",
      phpenv_root   => $php::config::root,
      version       => $version,
      homebrew_path => $boxen::config::homebrewdir,
      require       => Repository["${php::config::root}/php-src"],
    }

    # Set up config files

    file { $php_ini:
      content => template('php/php.ini.erb'),
      require => File["${version_config_root}"]
    }

    # Log files

    file { $error_log:
      owner => $::boxen_user,
      mode  => 644,
    }

    # PEAR cruft

    # Ensure pear cache folder is present
    file { "${version_data_root}/cache":
      ensure  => directory,
      require => File[$version_data_root],
    }

    # Set cache_dir for PEAR
    exec { "${dest}/bin/pear config-set cache_dir ${version_data_root}/cache":
      unless  => "${dest}/bin/pear config-get cache_dir | grep -i ${version_data_root}/cache",
      require => [
        Php_version[$version],
        File["${version_data_root}/cache"],
      ],
    }

    # Set download_dir for PEAR
    exec { "${dest}/bin/pear config-set download_dir ${version_data_root}/cache":
      unless  => "${dest}/bin/pear config-get download_dir | grep -i ${version_data_root}/cache",
      require => [
        Php_version[$version],
        File["${version_data_root}/cache"],
      ],
    }

  }
}
