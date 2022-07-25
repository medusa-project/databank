# # LICENSE INFO

class LicenseInfo < Struct.new(:code, :name, :external_info_url, :full_text_url )
end

LICENSE_INFO_ARR = Array.new

LICENSE_INFO_ARR.push(LicenseInfo.new("CC01", "CC0", "https://creativecommons.org/publicdomain/zero/1.0/", "#{Rails.root}/public/CC01.txt"))

LICENSE_INFO_ARR.push(LicenseInfo.new("CCBY4", "CC BY", "http://creativecommons.org/licenses/by/4.0/", "#{Rails.root}/public/CCBY4.txt"))

LICENSE_INFO_ARR.push(LicenseInfo.new(code="license.txt", name="Other License (license.txt must be uploaded as part of dataset)"))

class FunderInfo < Struct.new(:code, :name, :identifier, :display_position, :identifier_scheme)
end

FUNDER_INFO_ARR = Array.new

FUNDER_INFO_ARR.push(FunderInfo.new(code="IDCEO",
                                            name="Illinois Department of Commerce & Economic Opportunity (DCEO)",
                                            identifier= "10.13039/100004885",
                                            display_position=10,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="IDHS",
                                            name="Illinois Department of Human Services (DHS)",
                                            identifier= "10.13039/100004886",
                                            display_position=20,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="IDNR",
                                            name="Illinois Department of Natural Resources (IDNR)",
                                            identifier= "10.13039/100004887",
                                            display_position=30,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="IDOT",
                                            name="Illinois Department of Transportation (IDOT)",
                                            identifier= "10.13039/100009637",
                                            display_position=40,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="USARMY",
                                            name="U.S. Army",
                                            identifier= "10.13039/100006751",
                                            display_position=50,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="USDA",
                                            name="U.S. Department of Agriculture (USDA)",
                                            identifier= "10.13039/100000199",
                                            display_position=60,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="DOE",
                                            name="U.S. Department of Energy (DOE)",
                                            identifier= "10.13039/100000015",
                                            display_position=70,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="USGS",
                                            name="U.S. Geological Survey (USGS)",
                                            identifier= "10.13039/100000203",
                                            display_position=80,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="NASA",
                                            name="U.S. National Aeronautics and Space Administration (NASA)",
                                            identifier= "10.13039/100000104",
                                            display_position=90,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="NIH",
                                            name="U.S. National Institutes of Health (NIH)",
                                            identifier= "10.13039/100000002",
                                            display_position=100,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="NSF",
                                            name="U.S. National Science Foundation (NSF)",
                                            identifier= "10.13039/100000001",
                                            display_position=110,
                                            identifier_scheme="DOI"))

FUNDER_INFO_ARR.push(FunderInfo.new(code="other",
                                            name="Other -- Please provide name:",
                                            identifier= "",
                                            display_position="1000",
                                            identifier_scheme=""))
