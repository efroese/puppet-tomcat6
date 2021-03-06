# = Class: tomcat6
#
# Install the Apache Tomcat servlet container.
#
# == Parameters:
#
# $parentdir::               Where tomcat will be installed
#
# $tomcat_version::          The version of tomcat to install.
#
# $mirror::                  The apache mirror to download from.
#
# $tomcat_users_template::   A template to use to render the conf/tomcat-users.xml file.
#
# $tomcat_conf_template::    A template to use to render the conf/server.xml file.
#
# $tomcat_logging_template:: A template to use to render the conf/logging.properties file.
#
# $setenv_template::         A template to use to render the bin/setenv.sh file.
#
# $tomcat_user::             The system user the tomcat process will run as.
#
# $jmxremote_access_template:: JMX remote access file template.
#
# $jmxremote_password_template:: JMX remote password file template.
#
# $java_home::               Java installation.
#
# $jvm_route::               Java JVM route for load balancing.
#
# $shutdown_password::       Tomcat shutdown password
#
# $tomcat_group::            The system group the tomcat process will run as.
#
# $admin_user::              The admin user for the Tomcat Manager webapp
#
# $admin_password::          The admin password for the Tomcat Manager webapp
#
# == Actions:
#   Install the Apache Tomcat servlet container and configure the container, users, and logging.
#
# == Requires:
#   - Package['java']
#   - Module['Archive']
#
class tomcat6 ( $parentdir               = '/usr/local',
                $tomcat_version          = '6.0.35',
                $tomcat_major_version    = '6',
                $mirror                  = 'http://archive.apache.org/dist/tomcat',
                $digest_string           = '171d255cd60894b29a41684ce0ff93a8',
                $tomcat_users_template   = 'tomcat6/tomcat-users.xml.erb',
                $tomcat_conf_template    = 'tomcat6/server.xml.erb',
                $tomcat_logging_template = 'tomcat6/logging.properties.erb',
                $setenv_template         = 'tomcat6/setenv.sh.erb',
                $jmxremote_access_template = undef,
                $jmxremote_password_template = undef,
                $java_home               = '/usr/java/latest',
                $jvm_route               = 'jvm1',
                $shutdown_password       = 'SHUTDOWN',
                $admin_port              = 8005,
                $http_port               = 8080,
                $tomcat_user             = 'root',
                $tomcat_group            = 'root',
                $admin_user              = 'tomcat',
                $admin_password          = 'tomcat'
             ) {
                    
    $basedir     = "${parentdir}/tomcat"

    archive::download { "apache-tomcat-${tomcat_version}.tar.gz":
        ensure        => present,
        url           => "${mirror}/tomcat-${tomcat_major_version}/v${tomcat_version}/bin/apache-tomcat-${tomcat_version}.tar.gz",
        digest_string => $digest_string,
        src_target    => $parentdir,
    }

    archive::extract { "apache-tomcat-${tomcat_version}":
        ensure  => present,
        target  => $parentdir,
        src_target => $parentdir,
        require => Archive::Download["apache-tomcat-${tomcat_version}.tar.gz"],
        notify  => Exec["chown-apache-tomcat-${tomcat_version}"],
    }

    exec { "chown-apache-tomcat-${tomcat_version}":
        command => "chown -R ${tomcat_user}:${tomcat_group} ${parentdir}/apache-tomcat-${tomcat_version}/*",
        unless  => "[ `stat -c %U ${parentdir}/apache-tomcat-${tomcat_version}/conf` == ${tomcat_user} ]",
        require => Archive::Extract["apache-tomcat-${tomcat_version}"],
        refreshonly => true,
    }

    file { $basedir: 
        ensure => link,
        target => "${parentdir}/apache-tomcat-${tomcat_version}",
        require => Archive::Extract["apache-tomcat-${tomcat_version}"],
    }

    file { "${parentdir}/apache-tomcat-${tomcat_version}":
        ensure => directory,
        owner  => $tomcat_user,
        require => Archive::Extract["apache-tomcat-${tomcat_version}"],
    }

    file { "/etc/init.d/tomcat":
        ensure => present,
        owner  => root,
        group  => root,
        mode   => 0755,
        content => template('tomcat6/tomcat.init.erb'),
        require => File[$basedir],
    }

    file { '/var/log/tomcat':
        ensure => directory,
        owner  => root,
        group  => $tomcat_group,
        mode   => 0775,
    }

    file { "${parentdir}/apache-tomcat-${tomcat_version}/logs":
        ensure => link,
        target => "/var/log/tomcat",
        require => [ Archive::Extract["apache-tomcat-${tomcat_version}"], File['/var/log/tomcat'], ],
        force => true,
    }

    file { "${basedir}/conf/tomcat-users.xml":
        ensure => present,
        owner  => root,
        group  => root,
        mode   => 0644,
        content => template($tomcat_users_template),
        require => File[$basedir],
        notify  => Service['tomcat'],
    }

    file { "${basedir}/conf/server.xml":
        ensure => present,
        owner  => root,
        group  => root,
        mode   => 0644,
        content => template($tomcat_conf_template),
        require => File[$basedir],
        notify  => Service['tomcat'],
    }

    file { "${basedir}/conf/logging.properties":
        ensure => present,
        owner  => root,
        group  => root,
        mode   => 0644,
        content => template($tomcat_logging_template),
        require => File[$basedir],
        notify  => Service['tomcat'],
    }
    
    file { "${basedir}/bin/setenv.sh":
        ensure => present,
        owner  => root,
        group  => root,
        mode   => 0755,
        content => template($setenv_template),
        require => File[$basedir],
        notify  => Service['tomcat'],
    }

    if $jmxremote_access_template != undef {
        file { "${basedir}/conf/jmxremote.access":
            ensure => present,
            owner  => $tomcat_user,
            group  => $tomcat_group,
            mode   => 0600,
            content => template($jmxremote_access_template),
            require => File[$basedir],
            notify  => Service['tomcat'],
        }
    }

    if $jmxremote_password_template != undef {
        file { "${basedir}/conf/jmxremote.password":
            ensure => present,
            owner  => $tomcat_user,
            group  => $tomcat_group,
            mode   => 0600,
            content => template($jmxremote_password_template),
            require => File[$basedir],
            notify  => Service['tomcat'],
        }
    }

    file { "${basedir}/conf/Catalina":
        ensure => directory,
        owner  => $tomcat_user,
        group  => $tomcat_group,
        mode   => 0755,
        require => File[$basedir],
    }

    file { "${basedir}/conf/Catalina/localhost":
        ensure => directory,
        owner  => $tomcat_user,
        group  => $tomcat_group,
        mode   => 0755,
        require => File["${basedir}/conf/Catalina"],
    }

    service { 'tomcat':
        ensure  => running,
        enable => true,
        require => File["${basedir}/conf/tomcat-users.xml"]
    }

    define overlay($tomcat_home, $tarball_path, $creates, $user) {
        exec { "unpack-tomcat-overlay-${name}":
            cwd     => $tomcat_home,
            user    => $user,
            command => "tar xjf ${tarball_path}",
            creates => $creates,
            timeout => 0,
        }
    }
}
