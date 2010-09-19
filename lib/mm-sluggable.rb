require 'mongo_mapper'

module MongoMapper
  module Plugins
    module Sluggable
      def self.included(model)
        model.plugin self
      end

      module ClassMethods
        def sluggable(to_slug = :title, options = {})
          @slug_options = {
            :to_slug       => to_slug,
            :key           => :slug,
            :index         => true,
            :method        => :parameterize,
            :finder_method => :default_slug_finder,
            :scope         => nil,
            :callback      => :before_validation_on_create
          }.merge(options)


          # Don't use index if slug is not specified, in case this is an embedded
          # document.
          if @slug_options[:index]
            key @slug_options[:key], String, :index => @slug_options[:index]
          else
            key @slug_options[:key], String
          end

          self.send(@slug_options[:callback], :set_slug) if @slug_options[:callback]
        end

        def slug_options
          sluggable_class.instance_variable_get( :@slug_options )
        end
        
        def sluggable_class
          return self if @slug_options
          return self.superclass.sluggable_class unless self.superclass == Object
          nil
        end
      end

      module InstanceMethods
        def set_slug
          options = self.class.slug_options
          return unless self.send(options[:key]).blank?

          to_slug = self.send( options[:to_slug] )
          return if to_slug.blank?

          the_slug = raw_slug = to_slug.send(options[:method]).to_s

          conds = {}
          conds[options[:key]]   = the_slug
          conds[options[:scope]] = self.send(options[:scope]) if options[:scope]

          # todo - remove the loop and use regex instead so we can do it in one query
          i = 0
          while self.send( @slug_options[:finder_method], conds )
            i += 1
            conds[options[:key]] = the_slug = "#{raw_slug}-#{i}"
          end

          self.send(:"#{options[:key]}=", the_slug)
        end
        
        
        # override this to find an existing slug in a different manner
        # for class. #key# will be the test slug. scope will be the scope
        # if provided
        def default_slug_finder( conds )
          self.class.sluggable_class.where(conds).first
        end

      end
    end
  end
end