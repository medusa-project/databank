	module DatasetsHelper
		def restricted_access_buttons
			[
				{ path: login_path, class: "btn btn-primary btn-block idb", icon: 'log-in', text: 'Log in', role: 'button' },
				{ path: help_path,  class: "btn btn-success btn-block idb", icon: 'question-sign', text: 'Get Help', role: 'button' },
				{ path: root_path,  class: "btn btn-danger btn-block idb", icon: 'remove', text: 'Cancel', role: 'button' }
			]
		end
	end
