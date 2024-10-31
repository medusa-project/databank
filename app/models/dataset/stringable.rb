# frozen_string_literal: true

##
# This module supports string generation from dataset objects.
# It is used to generate plain text citations and structured data for google indexing.
# It is included in the Dataset model.


module Dataset::Stringable
  extend ActiveSupport::Concern

  def plain_text_citation
    creator_list = if creator_list == ""
                     "[Creator List]"
                   else
                     self.creator_list
                   end

    citationTitle = if title && title != ""
                      title
                    else
                      "[Title]"
                    end

    citation_id = persistent_url

    "#{creator_list} (#{publication_year}): #{citationTitle}. #{publisher}. #{citation_id}"
  end

  def to_datacite_json
    raise "not yet implemented"
  end

  def structured_data
    if publication_state == Databank::PublicationState::RELEASED

      return_string = ""

      return_string += %(<script type="application/ld+json">{"@context": "http://schema.org", "@type": "Dataset", "name": "#{title.gsub('"', '\\"')}")

      return_string += %(, "author": [)

      creators.each_with_index do |creator, index|
        return_string += ", " if index > 0

        if creator.identifier && creator.identifier != ""
          return_string += %({"@type": "Person", "name":"#{creator.given_name} #{creator.family_name}", "url":"http://orcid.org/#{creator.identifier}"})
        else
          return_string += %({"@type": "Person", "name":"#{creator.given_name} #{creator.family_name}"})
        end
      end
      return_string += "]"

      if keywords && keywords != ""

        keyword_arr = keywords.split(";")

        if !keyword_arr.empty?

          keyword_commas = ""

          keyword_arr.each_with_index do |keyword, i|
            keyword_commas += ", " if i != 0
            keyword_commas += keyword.strip
          end

          return_string += %(, "keywords": "#{keyword_commas}" )

        else
          return_string += %(, "keywords": "#{keyword_arr[0]}" )
        end

      end
      processed_description = if description && description != ""
        description.squish.to_json.delete_prefix('"').delete_suffix('"')
      else
        ""
                              end
      return_string += %(, "description":"#{processed_description}") if description
      return_string += %(, "version":"#{dataset_version}")
      return_string += %(, "url":"#{persistent_url}")
      return_string += %(, "sameAs":"#{IDB_CONFIG[:root_url_text]}/#{key}")
      if funders&.count&.positive?
        return_string += %(, "funder": [)
        funders.each_with_index do |funder, index|
          return_string += ", " if index > 0
          return_string += %({"@type": "Organization", "name":"#{funder.name}", "url":"https://doi.org/#{funder.identifier}"})
        end
        return_string += "]"
      end
      return_string += %(, "citation":"#{plain_text_citation.gsub('"', '\\"')}")
      license_link = nil
      LICENSE_INFO_ARR.each do |license_info|
        license_link = license_info.external_info_url if (license_info.code == license) && (license != "license.txt")
      end

      return_string += if license_link
                         %(, "license":"#{license_link}")
                       else
                         %(, "license":"See license.txt")
                       end

      return_string += %(, "includedInDataCatalog":{"@type":"DataCatalog", "name":"Illinois Data Bank", "url":"https://databank.illinois.edu"})

      return_string += %(}</script>)

      return_string

    else
      ""
    end
  end

  def record_text
    return "Method not valid for draft dataset." if !identifier || identifier == ""

    content = "##########################################################################################\n"
    content += "#  About this file:\n"
    content += "#  The dataset described in this info file was downloaded in part or in whole\n"
    content += "#  from the Illinois Data Bank.\n"
    content += "#  This info file contains citation information, a permanent digital object identifier (DOI),\n"
    content += "#  and a listing of all data files available for this dataset.\n"
    content += "#  Keep this info file so in the future you'll know where you obtained\n"
    content += "#  the data files you've just downloaded.\n"
    content += "##########################################################################################\n\n"

    content += "[ DOI: ] #{identifier}\n"
    content += "[ Title: ] #{title}\n"
    content += "[ #{'Creator'.pluralize(creators.count)}: ] #{creator_list}\n"
    content += "[ Publisher: ] #{publisher}\n"
    content += "[ Publication Year: ] #{publication_year}\n\n"

    content += "[ Citation: ] #{plain_text_citation}\n\n"

    content += "[ Description: ] #{description}\n\n" if description && description != ""

    content += "[ Keywords: ] #{keywords}\n" if keywords && keywords != ""

    content = case license
              when "CC01"
                content + "[ License: ] CC0 - https://creativecommons.org/publicdomain/zero/1.0/\n"
              when "CCBY4"
                content + "[ License: ] CC BY - http://creativecommons.org/licenses/by/4.0/\n"
              when "license.txt"
                content + "[ License: ] Custom - See license.txt file in dataset.\n"
              else
                content + "[ License: ] Not found.\n"
              end

    content += "[ Corresponding Creator: ] #{corresponding_creator_name}\n"

    if funders.count.positive?

      funders.each do |funder|
        content += "[ Funder: ] #{funder.name}"
        content += "- [ Grant: ] #{funder.grant}" if funder.grant && funder.grant != ""
      end

      content += "\n"

    end

    if related_materials.count.positive?

      related_materials.each do |material|
        if material.uri &&
          (material.relationship_arr.include?(Databank::Relationship::PREVIOUS_VERSION_OF) ||
            material.relationship_arr.include?(Databank::Relationship::NEW_VERSION_OF))
          # handled in versions section
        elsif material.citation || material.link
          content += "[ Related"
          content = if material.material_type && material.material_type != ""
                      content + " #{material.material_type}: ] "
                    else
                      content + "Material: ] "
                    end

          content += material.citation.to_s if material.citation && material.citation != ""

          content += ", " if material.citation && material.citation != "" && material.link && material.link != ""

          content += material.link.to_s if material.link && material.link != ""
        end
      end
    end

    content += "\n[ #{'File'.pluralize(datafiles.count)} (#{datafiles.count}): ] \n"

    complete_datafiles.each do |datafile|
      formatted_size = ApplicationController.helpers.number_to_human_size(datafile.bytestream_size)
      content += ". #{datafile.bytestream_name}, #{formatted_size}\n"
    end

    content
  end

  def store_agreement
    base_content = File.read(Rails.root.join("public", "deposit_agreement.txt"))

    agent_text = "License granted by #{depositor_name} on #{created_at.iso8601}\n\n"
    agent_text += "=================================================================================================================\n\n"
    agent_text += "  Are you a creator of this dataset or have you been granted permission by the creator to deposit this dataset?\n"
    agent_text += "  [x] Yes\n\n"
    agent_text += "  [ ] No\n\n"
    agent_text += "  Have you removed any private, confidential, or other legally protected information from the dataset?\n"
    agent_text += "  [#{removed_private == 'yes' ? 'x' : ' '}] Yes\n"
    agent_text += "  [#{removed_private == 'no' ? 'x' : ' '}] No\n"
    agent_text += "  [#{removed_private == 'na' ? 'x' : ' '}] N/A\n\n"
    agent_text += "  Do you agree to the Illinois Data Bank Deposit Agreement in its entirety?\n"
    agent_text += "  [x] Yes\n\n"
    agent_text += "  [ ] No\n\n"
    agent_text += "================================================================================================================="
    content = "#{agent_text}\n\n#{base_content}"

    StorageManager.instance.draft_root.write_string_to(draft_agreement_key, content)
    SystemFile.create(dataset_id: id, storage_root: "draft", storage_key: draft_agreement_key, file_type: "agreement")
  end

  def full_changelog
    changes = audits + associated_audits
    changes_arr = []
    changes.each do |change|
      change_hash = change.serializable_hash

      change_hash.delete("remote_address")
      change_hash.delete("request_uuid")
      user = nil
      user = User.find(Integer(change.user_id)) if change.user_id && change.user_id != ""
      agent = if user
                user.serializable_hash
              else
                {"user_id" => change.user_id}
              end
      changes_arr << {"change" => change_hash, "agent" => agent}
    rescue ArgumentError
      Rails.logger.warn("ArgumentError in changelog: #{change.to_yaml}")
    rescue StandardError => e
      raise e unless e.message.include?("BinaryUploader")
    end
    {"changes" => changes_arr}
  end

  def display_changelog
    main_exclude = []
    associated_exclude = []
    publication = nil

    begin
      audits.each do |change|
        if change.audited_changes.has_key?("medusa_uuid") ||
          change.audited_changes.has_key?("binary_name") ||
          change.audited_changes.has_key?("medusa_dataset_dir")
          main_exclude << change.id
        end

        next unless change.audited_changes.has_key?("publication_state")

        pub_change = change.audited_changes["publication_state"]
        if pub_change.class == Array && pub_change[0] == Databank::PublicationState::DRAFT
          publication = change.created_at
          main_exclude << change.id
        end
      end
    rescue StandardError => e
      raise e unless e.message.include?("BinaryUploader")
    end

    if publication
      changes = audits.where("created_at >= ?", publication).where.not(id: main_exclude)
      associated_changes = associated_audits.where("created_at >= ?", publication).where.not(id: associated_exclude)
      combined = changes + associated_changes
      sorted = combined.sort_by(&:created_at).reverse
      sorted
    else
      #Rails.logger.warn "no changes found for dataset #{attributes[:dataset_id]}"
      {}
    end
  end

  def creator_list
    creators_arr = Creator.where(dataset_id: id)
    if creators_arr.count.zero?
      "[Creator List]"
    elsif creators_arr.count == 1
      creator = creators_arr.first
      raise("mysteriously missing creator when creators.count #{creators_arr.count} was detected as equal to 1 #{creators_arr.to_yaml}") unless creator

      if creator.institution_name && creator.institution_name != "" || creator.family_name && creator.family_name != ""
        creator.list_name
      end
    else
      return_list = ""
      creators.each_with_index do |creator, i|
        return_list += "; " unless i.zero?
        return_list += creator.list_name
      end
      return_list
    end
  end

  def bibtex_creator_list
    if creators.count.zero?
      "[Creator List]"
    elsif creators.count == 1
      creator = creators.first
      if creator.institution_name && creator.institution_name != "" || creator.family_name && creator.family_name != ""
        creator.list_name
      end
    else
      return_list = ""
      creators.each_with_index do |creator, i|
        return_list += " and " unless i.zero?
        return_list += creator.list_name
      end
      return_list
    end
  end

  def contributor_list
    if contributors.count.zero?
      nil
    elsif contributors.count == 1
      contributor = contributors.first
      contributor.display_name
    else
      return_list = ""
      contributors.each_with_index do |contributor, i|
        return_list += "; " unless i.zero?
        return_list += contributor.display_name
      end
      return_list
    end
  end

  def recovery_serialization
    dataset = serializable_hash
    creators = []
    self.creators.each do |creator|
      creators << creator.serializable_hash
    end
    datafiles = []
    self.datafiles.each do |datafile|
      datafiles << datafile.serializable_hash
    end
    funders = []
    self.funders.each do |funder|
      funders << funder.serializable_hash
    end
    materials = []
    related_materials do |material|
      materials << material.serializable_hash
    end
    {"idb_dataset" => {"dataset"   => dataset,
                       "creators"  => creators,
                       "funders"   => funders,
                       "materials" => materials,
                       "datafiles" => datafiles}}
  end
end