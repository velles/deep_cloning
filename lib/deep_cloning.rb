# DeepCloning
#
# clones an ActiveRecord model. 
# if passed the :include option, it will deep clone the given associations
# if passed the :except option, it won't clone the given attributes
#
# === Usage:
# 
# ==== Cloning a model without an attribute
#   pirate.clone! :except => :name
# 
# ==== Cloning a model without multiple attributes
#   pirate.clone! :except => [:name, :nick_name]
# ==== Cloning one single association
#   pirate.clone! :include => :mateys
#
# ==== Cloning multiple associations
#   pirate.clone! :include => [:mateys, :treasures]
#
# ==== Cloning really deep
#   pirate.clone! :include => {:treasures => :gold_pieces}
#
# ==== Cloning really deep with multiple associations
#   pirate.clone! :include => [:mateys, {:treasures => :gold_pieces}]
#
# 
# Forked From at this: https://github.com/openminds/deep_cloning/
# but it doesn't handle foreign_keys correctly
#
# preforms a recursive deep_copy / clone on an object, saving referenced models as the "stack" unfolds
module DeepCloning
  def self.included(base) #:nodoc:
    base.alias_method_chain :deep_cloning
  end

  # @param [Hash] options 
  # defaults = {:exclude => [:updated_at, :created_at, :id], 
  #            :shallow => [],
  #            :include => []}
  #   :udated_at, :created_at and :id will always be in the exclude array, 
  #       even if a :exclude is passed through the formal parameter options
  #
  # @return [ActiveRecord::Base] the Object that was cloned
  def clone!(options = {})
    defaults = {:exclude => [:updated_at, :created_at, :id], 
                :include => []}
                
    options[:exclude] += defaults[:exclude] if options[:exclude]
    options = defaults.merge(options)
    our_foreign_key = self.class.to_s.foreign_key 
    
    # attributes not to clone at all
    skip_attributes = options[:exclude] or false 
    # list of associations to copy
    associations = options[:include] or false 
    # add current class to exclusions to prevent infinite loop
    options[:exclude] << our_foreign_key
    
    # doesn't save, only copies self's attributes
    kopy = self.clone
    
    Array(skip_attributes).each { |attribute|
      # attributes_from_column_definition is deprecated in rails > 2.3.8
      kopy[attribute] = attributes_from_column_definition[attribute.to_s]
    } if skip_attributes
    
    # save before we need self's id for has_many / has_one relationships
    kopy.save!
    
    if options[:include]
      Array(options[:include]).each do |association, deep_associations|
        if (association.kind_of? Hash)
          deep_associations = association[association.keys.first]
          association = association.keys.first
        end
        options[:include].merge!({:include => deep_associations.blank? {} : deep_associations})
        cloned_object = case self.class.reflect_on_association(association).macro
                        when :belongs_to, :has_one
                          ref_object = self.send(association).clone!(options)
                          kopy.send("#{association}=", ref_object[:id])
                          ref_object
                        when :has_many, :has_and_belongs_to_many
                          self.send(association).collect { |obj| 
                            ref_object = obj.clone!(options)
                            ref_object.send("#{our_foreign_key}=", kopy[:id]) if ref_object
                            ref_object
                          }
                        end
        kopy.send("#{association}=", cloned_object)
      end
    end
    
    kopy.save!
    
    return kopy
  end
end
