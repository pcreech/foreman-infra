# Deploys a set of jobs to one Jenkins instance
#
define jenkins_job_builder::config (
  Stdlib::Httpurl $url,
  String $username,
  String $password,
  Integer[0] $jenkins_jobs_update_timeout = 600,
  String $command_arguments = 'foreman-infra-jenkins-job-update',
) {
  $config_name = $name
  $directory = '/etc/jenkins_jobs'
  $inifile = "${directory}/jenkins_jobs_${config_name}.ini"

  file { "${directory}/${config_name}":
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    recurse => true,
    purge   => true,
    force   => true,
    source  => "puppet:///modules/jenkins_job_builder/${config_name}",
    notify  => Exec["jenkins-jobs-update-${config_name}"],
  }

  cron { "jenkins-jobs-update-${config_name}-delete-old":
    ensure      => absent,
    command     => "timeout 1h jenkins-jobs --conf ${inifile} update --delete-old ${directory}/${config_name} > /var/cache/jjb.xml",
    hour        => 0,
    minute      => 10,
    environment => 'PATH=/bin:/usr/bin:/usr/sbin',
    require     => File[$inifile],
  }

  exec { "jenkins-jobs-update-${config_name}":
    command => "jenkins-jobs --conf ${inifile} update ${directory}/${config_name} ${command_arguments}",
    timeout => $jenkins_jobs_update_timeout,
    path    => '/bin:/usr/bin:/usr/local/bin',
    require => File[$inifile],
  }

  cron { "remove-unmanaged-jobs-${config_name}":
    ensure      => absent,
    command     => "ruby ${directory}/${config_name}/unmanaged_jobs.rb ${inifile}",
    hour        => 1,
    minute      => 10,
    environment => 'PATH=/bin:/usr/bin:/usr/sbin',
    require     => File[$inifile],
  }

# TODO: We should put in  notify Exec['jenkins_jobs_update']
#       at some point, but that still has some problems.
  file { $inifile:
    ensure  => file,
    mode    => '0400',
    content => template('jenkins_job_builder/jenkins_jobs.ini.erb'),
  }
}
