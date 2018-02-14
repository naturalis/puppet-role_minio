# == Class: role_minio
#
# === Authors
#
# Author Name <atze.devries@naturalis.nl>
#
# === Copyright
#
# Apache2 license 2018.
#
class role_minio (
  $compose_version      = '1.17.1',
  $miniokey             = '12345',
  $miniosecret          = '12345678',
  $repo_source          = 'https://github.com/naturalis/docker-minio.git',
  $repo_ensure          = 'latest',
  $repo_dir             = '/opt/minio',
  $minio_data_dir       = '/data/s3-minio-test',
	$minio_url            = 's3-minio-test.naturalis.nl',
  $lets_encrypt_mail    = 'mail@example.com',
	$traefik_toml_file    = '/opt/traefik/traefik.toml',
	$traefik_acme_json    = '/opt/traefik/acme.json'

){

  include 'docker'
  include 'stdlib'

  Exec {
    path => '/usr/local/bin/',
    cwd  => "${role_minio::repo_dir}",
  }

  file { ['/data','/opt/traefik'] :
    ensure              => directory,
  }

	file { $traefik_toml_file :
		ensure   => file,
		content  => template('role_minio/traefik.toml.erb'),
		require  => File['/opt/traefik'],
		notify   => Exec['Restart containers on change'],
	}

  file { $traefik_acme_json :
		ensure   => present,
		mode     => '0600',
		require  => File['/opt/traefik'],
		notify   => Exec['Restart containers on change'],
	}

  file { "${role_minio::repo_dir}/.env":
		ensure   => file,
		content  => template('role_minio/prod.env.erb'),
    require  => Vcsrepo[$role_minio::repo_dir],
		notify   => Exec['Restart containers on change'],
	}

  class {'docker::compose': 
    ensure      => present,
    version     => $role_minio::compose_version
  }

  vcsrepo { $role_minio::repo_dir:
    ensure    => $role_minio::repo_ensure,
    source    => $role_minio::repo_source,
    provider  => 'git',
    user      => 'root',
    revision  => 'master',
    #    require   => Package['git'],
  }

	docker_network { 'web':
		ensure   => present,
	}

  docker_compose { "${role_minio::repo_dir}/docker-compose.yml":
    ensure      => present,
    require     => [ 
			Vcsrepo[$role_minio::repo_dir],
			File[$traefik_acme_json],
			File["${role_minio::repo_dir}/.env"],
			File[$traefik_toml_file],
			Docker_network['web']
		]
  }

  exec { 'Pull containers' :
    command  => 'docker-compose pull',
    schedule => 'everyday',
  }

  exec { 'Up the containers to resolve updates' :
    command  => 'docker-compose up -d',
    schedule => 'everyday',
    require  => Exec['Pull containers']
  }

  exec {'Restart containers on change':
	  refreshonly => true,
		command     => 'docker-compose up -d',
		require     => Docker_compose["${role_minio::repo_dir}/docker-compose.yml"],
	}

  # deze gaat per dag 1 keer checken
  # je kan ook een range aan geven, bv tussen 7 en 9 's ochtends
  schedule { 'everyday':
     period  => daily,
     repeat  => 1,
     range => '5-7',
  }

}
