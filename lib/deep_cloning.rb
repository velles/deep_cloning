# DeepCloning
#
# clones an ActiveRecord model. 
# if passed the :include option, it will deep clone the given associations
# if passed the :except option, it won't clone the given attributes
#
# === Usage:
# 
# ==== Cloning a model without an attribute
#   pirate.deep_dup! :except => :name
# 
# ==== Cloning a model without multiple attributes
#   pirate.deep_dup! :except => [:name, :nick_name]
#
# ==== Cloning one single association
#   pirate.deep_dup! :include => :mateys
#
# ==== Cloning multiple associations
#   pirate.deep_dup! :include => [:mateys, :treasures]
#
# ==== Cloning really deep
#   pirate.deep_dup! :include => {:treasures => :gold_pieces}
#
# ==== Cloning really deep with multiple associations
#   pirate.deep_dup! :include => [:mateys, {:treasures => :gold_pieces}]
#
# 
# Forked From at this: https://github.com/openminds/deep_cloning/
#
# preforms a recursive deep dup

module DeepDup
  # @param [Hash] options 
  # defaults = {:except => [:updated_at, :created_at, :id], 
  #            :include => []}
  #   :udated_at, :created_at and :id will always be in the exclude array, 
  #       even if a :exclude is passed through the formal parameter options
  #
  # @return [ActiveRecord::Base] the Object that was cloned
  def deep_dup(options = {})
    defaults = {:except => [:updated_at, :created_at, :id], 
                :include => []}

    exceptions = Array(options[:except])
    exceptions.concat(defaults[:except]) if options[:except]
    exceptions.uniq!
    
    options = defaults.merge(options)
    our_foreign_key = self.class.to_s.foreign_key 
    # attributes not to clone at all
    skip_attributes = options[:except].dup or false 
    # list of associations to copy
    associations = options[:include] or false 
    # add current class to exclusions to prevent infinite loop
    exceptions << our_foreign_key

    # duplicate original object
    kopy = self.dup

    if kopy.respond_to?("#{options[:previous_version_attr]}=")
      kopy.send("#{options[:previous_version_attr]}=", self)
    end
    
    Array(skip_attributes).each { |attribute|
      # attributes_from_column_definition is deprecated in rails > 2.3.8
      kopy[attribute] = self.class.column_defaults.dup[attribute.to_s]
    } 

    if options[:include]
      Array(options[:include]).each do |association, deep_associations|
        if (association.kind_of? Hash)
          deep_associations = association[association.keys.first]
          association = association.keys.first
        end
        
        options.merge!({:include => deep_associations.blank? ? {} : deep_associations})
        options[:except].uniq!

        reflected_association = self.class.reflect_on_association(association)
        next if reflected_association.nil?
        cloned_object = case reflected_association.macro
                        when :belongs_to, :has_one
                          ref_object = self.send(association).deep_dup(options)
                          kopy.send("#{association}=", ref_object[:id])
                          ref_object
                        when :has_many, :has_and_belongs_to_many
                          self.send(association).collect { |obj| 
                            ref_object = obj.deep_dup(options)
                            ref_object.send("#{our_foreign_key}=", kopy[:id]) if ref_object
                            ref_object
                          }
                        end
                                       
        kopy.send("#{association}=", cloned_object)
      end
    end

    return kopy
  end
end
require "active_record"
ActiveRecord::Base.send(:include, DeepDup)