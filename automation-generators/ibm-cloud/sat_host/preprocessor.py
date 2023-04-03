from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()
    g('type').isRequired().mustBeOneOf(['master', 'worker'])

    g('infrastructure.type').isRequired().mustBeOneOf(['vpc'])
    g('infrastructure.vpc_name').expandWith('vpc[*]').isRequired().mustBeOneOf('vpc[*]')
    g('infrastructure.subnet').expandWith('subnet[*]').isRequired().mustBeOneOf('subnet[*]')
    g('infrastructure.zone').lookupFromProperty('infrastructure.subnet','subnet','zone').isRequired()
    g('infrastructure.primary_ipv4_address').isOptional()
    g('infrastructure.bastion_host').isOptional()
    g('infrastructure.storage_profile').isRequired()
    g('infrastructure.volume_size_gb').isRequired()
    g('infrastructure.volume2_size_gb').isOptional()
    g('infrastructure.image').isRequired()
    g('infrastructure.allow_ip_spoofing').isOptional().mustBeOneOf([True,False])
    g('infrastructure.keys').isRequired()
    
    g('sat_location').expandWith('satellite[0]').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result
