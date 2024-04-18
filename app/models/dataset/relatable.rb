# frozen_string_literal: true

##
# This module is responsible for the relationship of datasets.
# It is included in the Dataset model.

module Dataset::Relatable
  extend ActiveSupport::Concern
  ##
  # Handles related materials
  # This method sets the related materials, cited materials, and external relationships for the dataset
  # It sets the related materials as those that are supplemental to or supplemented by the dataset
  # It sets the cited materials as those that cite the dataset
  # It sets the external relationships as those that are not version related

  attr_accessor :materials_related,
                :materials_cited_by,
                :num_external_relationships

  def handle_related_materials
    self.num_external_relationships = 0
    self.materials_related = self.materials_cited_by = []
    tmp_related = Set.new
    tmp_cited = Set.new
    tmp_external = Set.new
    if related_materials.count.positive?
      related_materials.each do |material|
        datacite_arr = []
        datacite_arr = material.datacite_list.split(",") if material.datacite_list && material.datacite_list != ""
        datacite_arr.each do |relationship|
          relationship = relationship.strip
          if [Databank::Relationship::NEW_VERSION_OF, Databank::Relationship::PREVIOUS_VERSION_OF].exclude?(relationship)
            tmp_external.add(material)
          end
          if [Databank::Relationship::SUPPLEMENT_TO, Databank::Relationship::SUPPLEMENTED_BY].include?(relationship)
            tmp_related.add(material)
          end
          tmp_cited.add(material) if relationship == Databank::Relationship::CITED_BY
        end
      end
    end
    self.materials_related = tmp_related.to_a
    self.materials_cited_by = tmp_cited.to_a
    self.num_external_relationships = tmp_external.count
  end

  ##
  # Related materials that are not version related
  # This method returns the related materials that are not version related
  # @return [Array] the related materials that are not version related
  def nonversion_related_materials
    relationship_arr = []
    related_materials.each do |material|
      relationship_arr << material if material.nonversion_relationships.count.positive?
    end
    relationship_arr
  end

  ##
  # Invalid material
  # This method returns whether the material is invalid
  # @param [Hash] attributes the attributes of the material
  # @return [Boolean] true if the link and citation are blank
  # Otherwise, it returns false
  def invalid_material(attributes)
    attributes["link"].blank? && attributes["citation"].blank?
  end

end
