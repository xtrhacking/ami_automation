<?php

declare(strict_types=1);

use App\Application\Actions\User\ListUsersAction;
use App\Application\Actions\User\ViewUserAction;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\App;
use Slim\Interfaces\RouteCollectorProxyInterface as Group;
use Slim\Views\Twig;
use Slim\Views\TwigMiddleware;




return function (App $app) {

    $twig = Twig::create('views', ['cache' => false]);
    $app->add(TwigMiddleware::create($app, $twig));

    // PDO MySQL connection
    $pdo = new PDO('mysql:host=mysql;dbname=playground', 'play', 'playground');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);


    $app->get('/static/{file}', function ($request, $response, $args) {
        $file = __DIR__ . '/public/static/' . $args['file'];
        if (file_exists($file)) {
            return $response->withHeader('Content-Type', mime_content_type($file))->write(file_get_contents($file));
        }
        return $response->withStatus(404);
    });

    $app->options('/{routes:.*}', function (Request $request, Response $response) {
        // CORS Pre-Flight OPTIONS Request Handler
        return $response;
    });

    function getBaseTemplateData($title) {
        return [
            'title' => $title,
            'topbar' => 'Catalog',
            'sidebar' => [
                'About' => '/about',
                'Names' => '/names'
                
               
            ]
        ];
    }


    $app->get('/', function ($request, $response, $args) use ($twig) {
        return $twig->render($response, 'home.twig', getBaseTemplateData('Home Page'));
    });;


    $app->get('/names', function ($request, $response, $args) use ($twig,$pdo) {
        $id = $request->getQueryParams()['use_emo'] ?? 1;
        $redisAvailable = false;
        $contacts = null;
        $redisStatus = "Redis - Not attempted";
        
        try {
            // Get Redis from container
            $redis = $this->get('redis');
            $redisStatus = "Redis - Instance created";
            
            // Test connection with ping
            if ($redis->ping('ping') == 'ping') {
                $redisAvailable = true;
                $redisStatus = "Redis - Connected successfully";
                
                // Cache key based on ID parameter
                $cacheKey = "contacts_" . $id;
                
                // Check if data exists in cache
                $contacts = $redis->get($cacheKey);
                
                if ($contacts) {
                    $contacts = unserialize($contacts);
                    $redisStatus .= " - Cache hit";
                } else {
                    $redisStatus .= " - Cache miss";
                }
                
            }
        } catch (\Exception $e) {
            // Log Redis connection error
            $redisStatus = "Error: " . $e->getMessage();
            error_log('Redis - connection error: ' . $e->getMessage());
        }
        
        // If no cache or Redis unavailable, fetch from database
        if (!$contacts) {
            $query = "SELECT * FROM CONTACT WHERE id IN ('1','2','3','4','" . $id . "','6','7','8','9','10')";
            $contacts = $pdo->query($query)->fetchAll(PDO::FETCH_ASSOC);
            
            // Store in cache if Redis is available
            if ($redisAvailable) {
                try {
                    $redis->setex($cacheKey, 600, serialize($contacts));
                } catch (\Exception $e) {
                    error_log('Redis cache write error: ' . $e->getMessage());
                }
            }
        }
      
        $data = getBaseTemplateData('Names Catalog');
            $data['description'] ="Catalogo de nomes";
            if (isset($request->getQueryParams()['use_emo'])) {
                $data['tip'] = "Nice did you find the parameter ;)";
            }
            else{
                $data['tip'] ="";
            
            }
            $data['contacts'] = $contacts;
            $data['instructions'] = $redisStatus; 
            $data['cmd'] = '';
            
            return $twig->render($response, 'service.twig', $data);
        
    });
    

    $app->get('/about', function ($request, $response, $args) use ($twig) {
        $data = getBaseTemplateData('About Us');
        return $twig->render($response, 'about.twig', $data);
    });

    


};
