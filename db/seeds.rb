# # This file should contain all the record creation needed to seed the database with its default values.
# # The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
# #
# # Examples:
# #
# #   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
# #   Mayor.create(name: 'Emanuel', city: cities.first)
#
# # LICENSE INFO
#
# license_cc01 = LicenseInfo.find_or_initialize_by(code: "CC01")
# license_cc01.name = "CC0"
# license_cc01.external_info_url = "https://creativecommons.org/publicdomain/zero/1.0/"
# license_cc01.full_text_url = "#{Rails.root}/public/CC01.txt"
# license_cc01.save!
#
# license_cc0BY4 = LicenseInfo.find_or_initialize_by(code: "CCBY4")
# license_cc0BY4.name = "CC BY"
# license_cc0BY4.external_info_url = "http://creativecommons.org/licenses/by/4.0/"
# license_cc0BY4.full_text_url = "#{Rails.root}/public/CCBY4.txt"
# license_cc0BY4.save!
#
# license_custom = LicenseInfo.find_or_initialize_by(code: "license.txt")
# license_custom.name = "Other License (license.txt must be uploaded as part of dataset)"
# license_custom.save!
#
# # FUNDER INFO
#
# funder_idceo = FunderInfo.find_or_initialize_by(code: "IDCEO")
# funder_idceo.name = "Illinois Department of Commerce & Economic Opportunity (DCEO)"
# funder_idceo.identifier = "10.13039/100004885"
# funder_idceo.display_position = 10
# funder_idceo.identifier_scheme = "DOI"
# funder_idceo.save!
#
# funder_idhs = FunderInfo.find_or_initialize_by(code: "IDHS")
# funder_idhs.name = "Illinois Department of Human Services (DHS)"
# funder_idhs.identifier = "10.13039/100004886"
# funder_idhs.display_position = 20
# funder_idhs.identifier_scheme = "DOI"
# funder_idhs.save!
#
# funder_idnr = FunderInfo.find_or_initialize_by(code: "IDNR")
# funder_idnr.name = "Illinois Department of Natural Resources (IDNR)"
# funder_idnr.identifier = "10.13039/100004887"
# funder_idnr.display_position = 30
# funder_idnr.identifier_scheme = "DOI"
# funder_idnr.save!
#
# funder_idot = FunderInfo.find_or_initialize_by(code: "IDOT")
# funder_idot.name = "Illinois Department of Transportation (IDOT)"
# funder_idot.identifier = ""
# funder_idot.display_position = 40
# funder_idot.identifier_scheme = ""
# funder_idot.save!
#
#
# funder_usarmy = FunderInfo.find_or_initialize_by(code: "USARMY")
# funder_usarmy.name = "U.S. Army"
# funder_usarmy.identifier = "10.13039/100006751"
# funder_usarmy.display_position = 50
# funder_usarmy.identifier_scheme = "DOI"
# funder_usarmy.save!
#
# funder_usda = FunderInfo.find_or_initialize_by(code: "USDA")
# funder_usda.name = "U.S. Department of Agriculture (USDA)"
# funder_usda.identifier = "10.13039/100000199"
# funder_usda.display_position = 60
# funder_usda.identifier_scheme = "DOI"
# funder_usda.save!
#
# funder_idoe = FunderInfo.find_or_initialize_by(code: "IDOE")
# if funder_idoe
#   funder_idoe.destroy
# end
#
# funder_doe = FunderInfo.find_or_initialize_by(code: "DOE")
# funder_doe.name = "U.S. Department of Energy (DOE)"
# funder_doe.identifier = "10.13039/100000015"
# funder_doe.display_position = 70
# funder_doe.identifier_scheme = "DOI"
# funder_doe.save!
#
# funder_idot = FunderInfo.find_or_initialize_by(code: "USGS")
# funder_idot.name = "U.S. Geological Survey (USGS)"
# funder_idot.identifier = "10.13039/100000203"
# funder_idot.display_position = 80
# funder_idot.identifier_scheme = "DOI"
# funder_idot.save!
#
# funder_nasa = FunderInfo.find_or_initialize_by(code: "NASA")
# funder_nasa.name = "U.S. National Aeronautics and Space Administration (NASA)"
# funder_nasa.identifier = "10.13039/100000104"
# funder_nasa.display_position = 90
# funder_nasa.identifier_scheme = "DOI"
# funder_nasa.save!
#
# funder_nih = FunderInfo.find_or_initialize_by(code: "NIH")
# funder_nih.name = "U.S. National Institutes of Health (NIH)"
# funder_nih.identifier = "10.13039/100000002"
# funder_nih.display_position = 100
# funder_nih.identifier_scheme = "DOI"
# funder_nih.save!
#
# funder_nsf = FunderInfo.find_or_initialize_by(code: "NSF")
# funder_nsf.name = "U.S. National Science Foundation (NSF)"
# funder_nsf.identifier = "10.13039/100000001"
# funder_nsf.display_position = 110
# funder_nsf.identifier_scheme = "DOI"
# funder_nsf.save!
#
# funder_other = FunderInfo.find_or_initialize_by(code: "other")
# funder_other.name = "Other -- Please provide name:"
# funder_other.identifier = ""
# funder_other.display_position = 1000
# funder_other.identifier_scheme = ""
# funder_other.save!

