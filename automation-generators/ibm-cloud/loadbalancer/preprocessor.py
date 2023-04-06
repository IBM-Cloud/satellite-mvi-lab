from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()
    g('subnet').isRequired()

    fc = g.getFullConfig()
    ge=g.getExpandedAttributes()

    if 'backends' in ge:
        for backend in ge['backends']:
            if 'name' not in backend:
                g.appendError(msg='property name must be specified for all elements in list backends')
            
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


